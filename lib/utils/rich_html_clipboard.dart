import 'rich_html_clipboard_stub.dart'
    if (dart.library.html) 'rich_html_clipboard_web.dart'
    as impl;

Future<bool> copyRichHtmlToClipboard(String htmlContent) {
  return impl.copyRichHtmlToClipboard(htmlContent);
}
