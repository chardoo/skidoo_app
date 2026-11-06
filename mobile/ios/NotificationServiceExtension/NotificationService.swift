import UserNotifications
import Intents

/// Rewrites every arriving push into the shape iOS draws a person with.
///
/// iOS has no "large icon" field. A push arrives and the system draws the app
/// icon beside it — the same square on every notification, whether it is a
/// message from somebody you talk to daily or a receipt. Android has
/// `large_icon` and solves this in the payload; iOS solves it exactly one way,
/// and this file is that way.
///
/// A **communication notification** (iOS 15+) is a notification iOS has been
/// told is from a person. Given an `INSendMessageIntent` naming that person and
/// carrying their picture, the system redraws it with their face large and
/// round at the leading edge and badges the app icon over its bottom-right
/// corner. That badge is not something this code draws — it is the system
/// saying "this came from a person, via this app", which is why it cannot be
/// imitated with an attachment, and why it looks right on every iOS version
/// that has it.
///
/// The server decides who that person is: `notify()` in main/app/services puts
/// their picture under `avatar`, their id under `actor` and their name under
/// `actor_name`, and sends none of the three for the notifications nobody sent
/// — a cashout, a payment, an admin decision. Those fall through untouched and
/// keep the app icon, which is right for them. A receipt is not from anybody.
/// See docs/NOTIFICATION_AVATARS.md in the backend repository.
///
/// ## No OneSignal here
///
/// The usual shape of this file links `OneSignalExtension` and hands the
/// request to it. This one does not, and the Podfile says why at length: both
/// ways of linking it into this particular project fail, and neither is worth
/// solving, because everything this extension reads is a key the backend
/// writes itself. What that costs is OneSignal's confirmed-delivery receipts,
/// which have never worked for this app — media attachments and delivery
/// confirmation both require an extension, and there was none until this one.
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard
            let content = request.content.mutableCopy() as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }
        self.bestAttempt = content

        let payload = content.userInfo
        let avatar = url(in: payload, key: "avatar")
        let picture = url(in: payload, key: "image")

        // Nothing to fetch. Finish now rather than spending a network round
        // trip to discover there was nothing to do — most notifications in the
        // system are from the app rather than from a person.
        if avatar == nil && picture == nil {
            contentHandler(content)
            return
        }

        // Both downloads run together and the notification waits for both, on
        // one clock. Serially they would cost two timeouts on a bad network,
        // and the second would be spent on a notification that is already late.
        let group = DispatchGroup()
        var face: Data?
        var attachment: UNNotificationAttachment?

        if let avatar = avatar {
            group.enter()
            fetch(avatar) { data in
                face = data
                group.leave()
            }
        }

        if let picture = picture {
            group.enter()
            download(picture) { file in
                attachment = file
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else {
                contentHandler(content)
                return
            }
            if let attachment = attachment {
                content.attachments = [attachment]
            }
            guard let face = face else {
                contentHandler(content)
                return
            }
            contentHandler(
                self.asCommunication(content, avatar: INImage(imageData: face))
            )
        }
    }

    /// The system's 30 seconds are up. Whatever has been assembled is shown —
    /// without this the *original* payload is displayed instead, losing the
    /// attachment and the face both.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let content = bestAttempt {
            contentHandler(content)
        }
    }

    // MARK: - The face

    /// Hand iOS an intent describing who this is from, and let it redraw.
    private func asCommunication(
        _ content: UNMutableNotificationContent,
        avatar: INImage
    ) -> UNNotificationContent {
        let payload = content.userInfo

        // The name under the face, which iOS also uses as the title once it
        // takes the notification over. The server sends it beside the picture;
        // the existing title is the fallback, since the sender's name is
        // usually the first thing it says anyway.
        let name = string(in: payload, key: "actor_name")
            ?? (content.title.isEmpty ? "jperg" : content.title)

        // `.unknown`, because our ids are not phone numbers or email
        // addresses. iOS still draws the avatar; it simply will not claim this
        // person is in your address book, which would not be true.
        let handle = INPersonHandle(
            value: string(in: payload, key: "actor"),
            type: .unknown
        )

        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: name,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: string(in: payload, key: "actor")
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            // What iOS groups the thread by. The id of the thing the
            // notification is about, so three comments on one photo collapse
            // the way three messages in one conversation do.
            conversationIdentifier: string(in: payload, key: "id"),
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        intent.setImage(avatar, forParameterNamed: \.sender)

        // Donated so the notification is attributed to this person. Focus
        // allowances and the suggestions row both read donations, and a
        // notification iOS cannot attribute is one a Focus mode may suppress.
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate(completion: nil)

        do {
            return try content.updating(from: intent)
        } catch {
            // iOS refuses the intent when the communication-notifications
            // entitlement is missing from the build. The notification still
            // has to arrive — it just arrives looking the way it did before
            // this target existed.
            return content
        }
    }

    // MARK: - Fetching

    private func fetch(_ url: URL, then done: @escaping (Data?) -> Void) {
        // Well inside the 30 seconds iOS allows an extension. A notification
        // that is late because a picture was slow is worse than one that is on
        // time wearing the app icon.
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.dataTask(with: request) { data, _, _ in
            done((data?.isEmpty == false) ? data : nil)
        }.resume()
    }

    /// The same, written to disk — an attachment is a file URL, not bytes.
    private func download(_ url: URL, then done: @escaping (UNNotificationAttachment?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        URLSession.shared.downloadTask(with: request) { temporary, response, _ in
            guard let temporary = temporary else {
                done(nil)
                return
            }
            // Moved out of the temporary location before this closure returns,
            // because the system deletes it the moment it does — and renamed
            // with an extension, since UNNotificationAttachment identifies the
            // media type from the path and silently rejects what it cannot
            // name.
            let suffix = Self.suffix(for: response, url: url)
            let destination = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString + suffix)
            do {
                try FileManager.default.moveItem(at: temporary, to: destination)
                done(try UNNotificationAttachment(identifier: "", url: destination))
            } catch {
                done(nil)
            }
        }.resume()
    }

    private static func suffix(for response: URLResponse?, url: URL) -> String {
        let fromPath = url.pathExtension
        if !fromPath.isEmpty, fromPath.count <= 4 {
            return "." + fromPath
        }
        // A CDN URL need not end in .jpg — ours often carry transforms instead
        // — so the content type is the answer when the path has nothing.
        switch (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type")?
            .lowercased()
        {
        case let type? where type.contains("png"): return ".png"
        case let type? where type.contains("gif"): return ".gif"
        case let type? where type.contains("mp4"): return ".mp4"
        default: return ".jpg"
        }
    }

    // MARK: - Reading the payload

    private func url(in payload: [AnyHashable: Any], key: String) -> URL? {
        guard let value = string(in: payload, key: key) else { return nil }
        return URL(string: value)
    }

    private func string(in payload: [AnyHashable: Any], key: String) -> String? {
        // Two places to look. OneSignal nests whatever the server sent as
        // `data` under `custom.a`, and lifts nothing to the top level that it
        // does not recognise — but a push delivered through any other path
        // puts it at the top. Checking both means neither has to be the one
        // that works.
        if let value = payload[key] as? String, !value.isEmpty {
            return value
        }
        if
            let custom = payload["custom"] as? [AnyHashable: Any],
            let additional = custom["a"] as? [AnyHashable: Any],
            let value = additional[key] as? String,
            !value.isEmpty
        {
            return value
        }
        return nil
    }
}
