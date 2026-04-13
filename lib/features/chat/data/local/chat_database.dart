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
  static const _dbVersion = 2;

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
        id            TEXT PRIMARY KEY,
        room_id       TEXT NOT NULL,
        sender_id     TEXT NOT NULL,
        sender_name   TEXT NOT NULL DEFAULT '',
        sender_role   TEXT NOT NULL,
        content       TEXT NOT NULL DEFAULT '',
        image_url     TEXT,
        reply_to_id   TEXT,
        reply_preview TEXT,
        created_at    TEXT NOT NULL,
        is_read       INTEGER NOT NULL DEFAULT 0,
        is_local      INTEGER NOT NULL DEFAULT 0
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
  }

  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<void> upsertRoom(ChatRoom room) async {
    final db = await _database;
    await db.insert(
      'chat_rooms',
      _roomToRow(room),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertRooms(List<ChatRoom> rooms) async {
    final db = await _database;
    final batch = db.batch();
    for (final room in rooms) {
      batch.insert(
        'chat_rooms',
        _roomToRow(room),
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
        // Preserve is_read=1 when re-fetching from server.
        // The server does not return read status, so we must not let a
        // re-fetch reset a message the user has already read.
        await txn.rawInsert(
          '''
          INSERT INTO chat_messages
            (id, room_id, sender_id, sender_name, sender_role, content,
             image_url, reply_to_id, reply_preview, created_at, is_read, is_local)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            room_id      = excluded.room_id,
            sender_id    = excluded.sender_id,
            sender_name  = excluded.sender_name,
            sender_role  = excluded.sender_role,
            content      = excluded.content,
            image_url    = excluded.image_url,
            reply_to_id  = excluded.reply_to_id,
            reply_preview= excluded.reply_preview,
            created_at   = excluded.created_at,
            is_read      = MAX(is_read, excluded.is_read),
            is_local     = excluded.is_local
          ''',
          [
            msg.id,
            msg.roomId,
            msg.senderId,
            msg.senderName,
            msg.senderRole,
            msg.content,
            msg.imageUrl,
            msg.replyToId,
            msg.replyPreview != null ? jsonEncode(msg.replyPreview!.toJson()) : null,
            msg.createdAt.toIso8601String(),
            msg.isRead ? 1 : 0,
            msg.isLocal ? 1 : 0,
          ],
        );
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
        _messageToRow(message),
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
        'reply_to_id': msg.replyToId,
        'reply_preview': msg.replyPreview != null
            ? jsonEncode(msg.replyPreview!.toJson())
            : null,
        'created_at': msg.createdAt.toIso8601String(),
        'is_read': msg.isRead ? 1 : 0,
        'is_local': msg.isLocal ? 1 : 0,
      };

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
      replyToId: row['reply_to_id'] as String?,
      replyPreview: preview,
      createdAt: DateTime.parse(row['created_at'] as String),
      isRead: (row['is_read'] as int) == 1,
      isLocal: (row['is_local'] as int) == 1,
    );
  }
}
