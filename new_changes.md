 First event you receive:                                                                                                                               
  { "type": "connected", "userId": "...", "rooms": [{"room_id":"...", "room_type":"direct", "name":null}, ...] }                                         
  Then per DM room you'll receive key_bundles events for E2EE setup.                                                                                     
                                                                                                                                                         
  Send any event — just add room_id:                                                                                                                     
  { "type": "message",      "room_id": "abc", "content": "hello" }                                                                                       
  { "type": "like",         "room_id": "abc", "event_id": "xyz" }                                                                                        
  { "type": "picture_like", "room_id": "abc", "picture_id": "xyz" }                                                                                      
  { "type": "ack",          "room_id": "abc", "message_id": "..." }                                                                                      
                                                                                                                                                         
  After joining a new room via REST:                                                                                                                     
  { "type": "subscribe_room", "room_id": "new-room-id" }                                                                                                 
  Server verifies membership and starts delivering that room's events — no reconnect needed.                                                             
                                                                                                                                                         
  The per-room endpoint (/chat/ws/{room_id}) still works — nothing breaks for any existing connections while you migrate Flutter.                        
                                                                                                                                                         
✻