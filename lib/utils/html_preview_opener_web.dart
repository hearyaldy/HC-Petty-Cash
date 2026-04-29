import 'dart:html' as html;

Future<bool> openHtmlPreview(String htmlContent) async {
  final openedWindow = html.window.open('about:blank', '_blank') as dynamic;
  openedWindow.document.open();
  openedWindow.document.write(htmlContent);
  openedWindow.document.close();
  return true;
}
