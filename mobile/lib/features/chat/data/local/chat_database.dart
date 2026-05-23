import 'dart:convert';

import 'package:path/path.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite cache for rooms and messages.
///
/// Schema version history:
///   v1 – initial: chat_rooms + chat_messages tables.
///   v2 – added sender_name, image_url, reply_to_id, reply_preview columns.
class ChatDatabase {
  static const _dbName = 'skidoo_chat.db';
  static const _dbVersion = 5;

  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chat_rooms (
        id          TEXT PRIMARY KEY,
        type        TEXT NOT NULL,
        event_id    TEXT,
        name        TEXT,
        created_at  TEXT NOT NULL,
        participants TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id                  TEXT PRIMARY KEY,
        room_id             TEXT NOT NULL,
        sender_id           TEXT NOT NULL,
        sender_name         TEXT NOT NULL DEFAULT '',
        sender_role         TEXT NOT NULL,
        content             TEXT NOT NULL DEFAULT '',
        image_url           TEXT,
        is_video            INTEGER NOT NULL DEFAULT 0,
        reply_to_id         TEXT,
        reply_preview       TEXT,
        created_at          TEXT NOT NULL,
        is_read             INTEGER NOT NULL DEFAULT 0,
        is_local            INTEGER NOT NULL DEFAULT 0,
        is_encrypted        INTEGER NOT NULL DEFAULT 0,
        iv                  TEXT,
        ephemeral_key       TEXT,
        sender_identity_key TEXT,
        otpk_id             INTEGER,
        spk_id              INTEGER,
        updated_at          TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_msg_room_time ON chat_messages(room_id, created_at DESC)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE chat_messages ADD COLUMN sender_name TEXT NOT NULL DEFAULT ''");
      await db.execute('ALTER TABLE chat_messages ADD COLUMN image_url TEXT');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN reply_to_id TEXT');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN reply_preview TEXT');
    }
    if (oldVersion < 3) {
      final cols = await db.rawQuery('PRAGMA table_info(chat_messages)');
      final hasIsVideo = cols.any((c) => c['name'] == 'is_video');
      if (!hasIsVideo) {
        await db.execute(
            'ALTER TABLE chat_messages ADD COLUMN is_video INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE chat_messages ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN iv TEXT');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN ephemeral_key TEXT');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN sender_identity_key TEXT');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN otpk_id INTEGER');
      await db.execute('ALTER TABLE chat_messages ADD COLUMN spk_id INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE chat_messages ADD COLUMN updated_at TEXT');
    }
  }

  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<void> upsertRoom(ChatRoom room) async {
    final db = await _database;
    await db.insert(
      'chat_rooms',
      _nonNullRow(_roomToRow(room)),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertRooms(List<ChatRoom> rooms) async {
    final db = await _database;
    final batch = db.batch();
    for (final room in rooms) {
      batch.insert(
        'chat_rooms',
        _nonNullRow(_roomToRow(room)),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ChatRoom>> getAllRooms() async {
    final db = await _database;
    final rows = await db.query('chat_rooms', orderBy: 'created_at DESC');
    return rows.map(_rowToRoom).toList();
  }

  Future<ChatRoom?> getRoom(String id) async {
    final db = await _database;
    final rows =
        await db.query('chat_rooms', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToRoom(rows.first);
  }

  /// Returns a cached direct room that includes [recipientId] as a participant,
  /// or null if none is found. Used to avoid duplicate room creation.
  Future<ChatRoom?> getDirectRoomWithUser(String recipientId) async {
    final db = await _database;
    final rows = await db.query(
      'chat_rooms',
      where: "type = 'direct'",
    );
    for (final row in rows) {
      final room = _rowToRoom(row);
      if (room.participants.any((p) => p.userId == recipientId)) return room;
    }
    return null;
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<void> upsertMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      for (final msg in messages) {
        // Remove any optimistic placeholder for this content + image combination.
        // The IS operator handles NULL correctly in SQLite.
        await txn.delete(
          'chat_messages',
          where: 'room_id = ? AND is_local = 1 AND content = ? AND image_url IS ?',
          whereArgs: [msg.roomId, msg.content, msg.imageUrl],
        );

        // Check whether a row with this id already exists so we can
        // preserve is_read=1 and decrypted content across server re-fetches.
        final existing = await txn.query(
          'chat_messages',
          columns: ['is_read', 'is_encrypted'],
          where: 'id = ?',
          whereArgs: [msg.id],
          limit: 1,
        );

        if (existing.isEmpty) {
          // New message — insert without passing Null-typed values to sqflite
          // (the column defaults to NULL when the key is absent from the map).
          await txn.insert(
            'chat_messages',
            _nonNullRow(_messageToRow(msg)),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else {
          final wasRead = (existing.first['is_read'] as int) == 1;
          final wasDecrypted = (existing.first['is_encrypted'] as int) == 0;

          final updateRow = <String, Object?>{
            'room_id': msg.roomId,
            'sender_id': msg.senderId,
            'sender_name': msg.senderName,
            'sender_role': msg.senderRole,
            'image_url': msg.imageUrl,
            'is_video': msg.isVideo ? 1 : 0,
            'reply_to_id': msg.replyToId,
            'reply_preview': msg.replyPreview != null
                ? jsonEncode(msg.replyPreview!.toJson())
                : null,
            'created_at': msg.createdAt.toIso8601String(),
            'is_local': msg.isLocal ? 1 : 0,
            // Preserve is_read=1 if the user already read this message.
            'is_read': wasRead || msg.isRead ? 1 : 0,
          };

          // Only overwrite E2EE / content fields when the stored copy is still
          // encrypted. Once decrypted, the plaintext is authoritative.
          if (!wasDecrypted) {
            updateRow['content'] = msg.content;
            updateRow['is_encrypted'] = msg.isEncrypted ? 1 : 0;
            updateRow['iv'] = msg.iv;
            updateRow['ephemeral_key'] = msg.ephemeralKey;
            updateRow['sender_identity_key'] = msg.senderIdentityKey;
            updateRow['otpk_id'] = msg.otpkId;
            updateRow['spk_id'] = msg.senderSpkId;
          }

          await txn.update(
            'chat_messages',
            _nonNullRow(updateRow),
            where: 'id = ?',
            whereArgs: [msg.id],
          );
        }
      }
    });
  }

  /// Inserts a confirmed (server) message and removes any optimistic placeholder
  /// with matching content so duplicates never appear in the cache.
  Future<void> insertMessage(ChatMessage message) async {
    final db = await _database;
    await db.transaction((txn) async {
      // Delete the matching optimistic placeholder if present.
      // Match on content + image_url so image-only messages don't accidentally
      // wipe unrelated local placeholders (SQLite IS handles NULL correctly).
      await txn.delete(
        'chat_messages',
        where: 'room_id = ? AND is_local = 1 AND content = ? AND image_url IS ?',
        whereArgs: [message.roomId, message.content, message.imageUrl],
      );
      await txn.insert(
        'chat_messages',
        _nonNullRow(_messageToRow(message)),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<ChatMessage>> getMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
  }) async {
    final db = await _database;

    if (beforeId != null) {
      // Cursor-based pagination: find the created_at of the cursor message.
      final cursor = await db.query(
        'chat_messages',
        columns: ['created_at'],
        where: 'id = ?',
        whereArgs: [beforeId],
      );
      if (cursor.isNotEmpty) {
        final cursorTime = cursor.first['created_at'] as String;
        final rows = await db.query(
          'chat_messages',
          where: 'room_id = ? AND created_at < ?',
          whereArgs: [roomId, cursorTime],
          orderBy: 'created_at DESC',
          limit: limit,
        );
        return rows.map(_rowToMessage).toList();
      }
    }

    final rows = await db.query(
      'chat_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_rowToMessage).toList();
  }

  Future<void> deleteMessage(String id) async {
    final db = await _database;
    await db.delete('chat_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMessageContent(
      String id, String content, DateTime updatedAt) async {
    final db = await _database;
    await db.update(
      'chat_messages',
      {'content': content, 'updated_at': updatedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRoom(String roomId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('chat_rooms', where: 'id = ?', whereArgs: [roomId]);
      await txn
          .delete('chat_messages', where: 'room_id = ?', whereArgs: [roomId]);
    });
  }

  /// Returns the timestamp of the most recent confirmed (non-local) message
  /// for every room that has at least one message in the cache.
  Future<Map<String, DateTime>> getLastMessageTimes() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT room_id, MAX(created_at) AS last_at FROM chat_messages WHERE is_local = 0 GROUP BY room_id',
    );
    return {
      for (final r in rows)
        r['room_id'] as String: DateTime.parse(r['last_at'] as String),
    };
  }

  /// Returns unread message counts per room, excluding the given user's own
  /// messages, already-read ones, and public event discussion rooms.
  Future<Map<String, int>> getUnreadCounts(String currentUserId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT m.room_id, COUNT(*) AS cnt
      FROM chat_messages m
      JOIN chat_rooms r ON r.id = m.room_id
      WHERE m.sender_id != ?
        AND m.is_read = 0
        AND m.is_local = 0
        AND r.type != 'event'
      GROUP BY m.room_id
      ''',
      [currentUserId],
    );
    return {
      for (final r in rows) r['room_id'] as String: r['cnt'] as int,
    };
  }

  /// Marks all messages in [roomId] as read.
  Future<void> markAllAsRead(String roomId) async {
    final db = await _database;
    await db.update(
      'chat_messages',
      {'is_read': 1},
      where: 'room_id = ? AND is_read = 0',
      whereArgs: [roomId],
    );
  }

  Future<void> deleteLocalMessages(String roomId) async {
    final db = await _database;
    await db.delete(
      'chat_messages',
      where: 'room_id = ? AND is_local = 1',
      whereArgs: [roomId],
    );
  }

  /// Wipes all cached rooms and messages. Called when a different user logs in
  /// so that one account's chat history never leaks into another's.
  Future<void> clearAll() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('chat_messages');
      await txn.delete('chat_rooms');
    });
  }

  // ── Mappers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _roomToRow(ChatRoom room) => {
        'id': room.id,
        'type': room.type.toApiString(),
        'event_id': room.eventId,
        'name': room.name,
        'created_at': room.createdAt.toIso8601String(),
        'participants':
            jsonEncode(room.participants.map((p) => p.toJson()).toList()),
      };

  ChatRoom _rowToRoom(Map<String, dynamic> row) {
    final participantsJson =
        jsonDecode(row['participants'] as String) as List<dynamic>;
    return ChatRoom(
      id: row['id'] as String,
      type: RoomType.fromString(row['type'] as String?),
      eventId: row['event_id'] as String?,
      name: row['name'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      participants: participantsJson
          .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _messageToRow(ChatMessage msg) => {
        'id': msg.id,
        'room_id': msg.roomId,
        'sender_id': msg.senderId,
        'sender_name': msg.senderName,
        'sender_role': msg.senderRole,
        'content': msg.content,
        'image_url': msg.imageUrl,
        'is_video': msg.isVideo ? 1 : 0,
        'reply_to_id': msg.replyToId,
        'reply_preview': msg.replyPreview != null
            ? jsonEncode(msg.replyPreview!.toJson())
            : null,
        'created_at': msg.createdAt.toIso8601String(),
        'is_read': msg.isRead ? 1 : 0,
        'is_local': msg.isLocal ? 1 : 0,
        'is_encrypted': msg.isEncrypted ? 1 : 0,
        'iv': msg.iv,
        'ephemeral_key': msg.ephemeralKey,
        'sender_identity_key': msg.senderIdentityKey,
        'otpk_id': msg.otpkId,
        'spk_id': msg.senderSpkId,
        'updated_at': msg.updatedAt?.toIso8601String(),
      };

  /// Removes entries with null values before passing to sqflite insert/update.
  /// SQLite uses the column DEFAULT (NULL) for omitted columns on INSERT,
  /// and leaves the column unchanged on UPDATE — both are correct here.
  /// This avoids the "argument null with type Null" sqflite warning caused by
  /// passing Dart's Null type through raw SQL parameter lists.
  Map<String, Object> _nonNullRow(Map<String, Object?> row) => Map.fromEntries(
        row.entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    ReplyPreview? preview;
    final previewStr = row['reply_preview'] as String?;
    if (previewStr != null) {
      try {
        preview = ReplyPreview.fromJson(
            jsonDecode(previewStr) as Map<String, dynamic>);
      } catch (_) {}
    }
    return ChatMessage(
      id: row['id'] as String,
      roomId: row['room_id'] as String,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String? ?? '',
      senderRole: row['sender_role'] as String,
      content: row['content'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      isVideo: (row['is_video'] as int?) == 1,
      replyToId: row['reply_to_id'] as String?,
      replyPreview: preview,
      createdAt: DateTime.parse(row['created_at'] as String),
      isRead: (row['is_read'] as int) == 1,
      isLocal: (row['is_local'] as int) == 1,
      isEncrypted: (row['is_encrypted'] as int?) == 1,
      iv: row['iv'] as String?,
      ephemeralKey: row['ephemeral_key'] as String?,
      senderIdentityKey: row['sender_identity_key'] as String?,
      otpkId: row['otpk_id'] as int?,
      senderSpkId: row['spk_id'] as int?,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }
}
