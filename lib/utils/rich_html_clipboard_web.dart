import 'dart:html' as html;

Future<bool> copyRichHtmlToClipboard(String htmlContent) async {
  final container = html.DivElement()
    ..setAttribute('contenteditable', 'true')
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '0'
    ..style.opacity = '0'
    ..style.pointerEvents = 'none'
    ..innerHtml = htmlContent;

  html.document.body?.append(container);

  final selection = html.window.getSelection();
  if (selection == null) {
    container.remove();
    return false;
  }

  selection.removeAllRanges();
  final range = html.Range();
  range.selectNodeContents(container);
  selection.addRange(range);

  final success = html.document.execCommand('copy');

  selection.removeAllRanges();
  container.remove();
  return success;
}
