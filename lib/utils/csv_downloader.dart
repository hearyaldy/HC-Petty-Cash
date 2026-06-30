import 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart'
    as impl;

void downloadCsvFile(String csvContent, String filename) =>
    impl.downloadFile(csvContent, filename, 'text/csv;charset=utf-8');

void downloadTextFile(String content, String filename) =>
    impl.downloadFile(content, filename, 'text/plain;charset=utf-8');
