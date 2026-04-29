import 'html_preview_opener_stub.dart'
    if (dart.library.html) 'html_preview_opener_web.dart'
    as impl;

Future<bool> openHtmlPreview(String htmlContent) {
  return impl.openHtmlPreview(htmlContent);
}
