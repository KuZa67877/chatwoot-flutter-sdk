# Chatwoot SDK example app

This app demonstrates [`ChatwootClient`](https://pub.dev/packages/chatwoot_sdk) from the local `chatwoot_sdk` package.

The chat UI is built with [**flutter_chat_ui**](https://pub.dev/packages/flutter_chat_ui) / `flutter_chat_core`: the `Chat` widget, `InMemoryChatController`, and messages mapped from the SDK domain models.

## Running

From the `example/` directory:

```bash
flutter pub get
flutter run \
  --dart-define=CHATWOOT_INBOX_IDENTIFIER=your_inbox_identifier \
  --dart-define=CHATWOOT_BASE_URL=https://your-chatwoot.example.com/
```

Or via a file (see [`.env.example`](.env.example)):

```bash
cp .env.example .env
# edit .env
flutter run --dart-define-from-file=.env
```

If `CHATWOOT_BASE_URL` is not set, the build falls back to `https://app.chatwoot.com`. Set your own URL for real usage.

## What the example shows

- **`defaultCreds`** and `--dart-define` for identity (`CHATWOOT_IDENTIFIER`, `CHATWOOT_IDENTIFIER_HASH`, name, email, phone).
- **`bootstrap`**, the **`conversations`** list, **`refreshConversations`**, and **`createConversation`**.
- **`markConversationRead`**, the **`unreadCount`** counter, and **`resolveConversation`**.
- Realtime: **`connectionState`** in the header, **`events`** to SnackBar for new messages and conversation status changes.
- Chat: **`sendMessage`**, **`toggleTyping`**, attachments via **`image_picker`** and **`sendMessage(attachments: ...)`**.
- Send failure: tap a text bubble marked "Not delivered" to call **`retryMessage`**.
- Profile (person icon in the AppBar): **`updateContact`**, **`authorize`**, and **`logout`**.

## Platforms

Local image previews from the file system are not used on **web** (`Image.file` is unavailable); HTTP(S) attachments use `Image.network`.
