import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

// Text formatting settings for the letter
class LetterFormatting {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final String textAlign; // 'left', 'center', 'right', 'justify'
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  LetterFormatting({
    this.fontFamily = 'Sarabun',
    this.fontSize = 12,
    this.lineHeight = 1.5,
    this.textAlign = 'left',
    this.marginTop = 20,
    this.marginBottom = 20,
    this.marginLeft = 40,
    this.marginRight = 40,
  });

  Map<String, dynamic> toMap() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'textAlign': textAlign,
      'marginTop': marginTop,
      'marginBottom': marginBottom,
      'marginLeft': marginLeft,
      'marginRight': marginRight,
    };
  }

  factory LetterFormatting.fromMap(Map<String, dynamic>? map) {
    if (map == null) return LetterFormatting();
    return LetterFormatting(
      fontFamily: map['fontFamily'] as String? ?? 'Sarabun',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 12,
      lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.5,
      textAlign: map['textAlign'] as String? ?? 'left',
      marginTop: (map['marginTop'] as num?)?.toDouble() ?? 20,
      marginBottom: (map['marginBottom'] as num?)?.toDouble() ?? 20,
      marginLeft: (map['marginLeft'] as num?)?.toDouble() ?? 40,
      marginRight: (map['marginRight'] as num?)?.toDouble() ?? 40,
    );
  }

  LetterFormatting copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    String? textAlign,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
  }) {
    return LetterFormatting(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      textAlign: textAlign ?? this.textAlign,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
    );
  }
}

class EmploymentLetterTemplate {
  final String id;
  final String title;
  final String content; // The template content with placeholders
  final String? description;
  final bool isActive;
  final LetterFormatting formatting;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmploymentLetterTemplate({
    required this.id,
    required this.title,
    required this.content,
    this.description,
    this.isActive = true,
    LetterFormatting? formatting,
    required this.createdAt,
    this.updatedAt,
  }) : formatting = formatting ?? LetterFormatting();

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'description': description,
      'isActive': isActive,
      'formatting': formatting.toMap(),
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : null,
    };
  }

  factory EmploymentLetterTemplate.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('EmploymentLetterTemplate document ${doc.id} has no data');
    }

    // Parse createdAt with fallback
    DateTime createdAt;
    if (data['createdAt'] != null && data['createdAt'] is firestore.Timestamp) {
      createdAt = (data['createdAt'] as firestore.Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    return EmploymentLetterTemplate(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Template',
      content: data['content'] as String? ?? '',
      description: data['description'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      formatting: LetterFormatting.fromMap(data['formatting'] as Map<String, dynamic>?),
      createdAt: createdAt,
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is firestore.Timestamp
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  EmploymentLetterTemplate copyWith({
    String? id,
    String? title,
    String? content,
    String? description,
    bool? isActive,
    LetterFormatting? formatting,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmploymentLetterTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      formatting: formatting ?? this.formatting,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EmploymentLetter {
  final String id;
  final String templateId;
  final String staffId;
  final String staffName;
  final String staffPosition;
  final String staffDepartment;
  final String? customContent; // Customized content for this specific letter
  final LetterFormatting? customFormatting; // Custom formatting for this letter
  final String? generatedPdfUrl; // URL to the generated PDF
  final DateTime issuedDate;
  final String? issuedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmploymentLetter({
    required this.id,
    required this.templateId,
    required this.staffId,
    required this.staffName,
    required this.staffPosition,
    required this.staffDepartment,
    this.customContent,
    this.customFormatting,
    this.generatedPdfUrl,
    required this.issuedDate,
    this.issuedBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'templateId': templateId,
      'staffId': staffId,
      'staffName': staffName,
      'staffPosition': staffPosition,
      'staffDepartment': staffDepartment,
      'customContent': customContent,
      'customFormatting': customFormatting?.toMap(),
      'generatedPdfUrl': generatedPdfUrl,
      'issuedDate': firestore.Timestamp.fromDate(issuedDate),
      'issuedBy': issuedBy,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : null,
    };
  }

  factory EmploymentLetter.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('EmploymentLetter document ${doc.id} has no data');
    }

    // Parse issuedDate with fallback
    DateTime issuedDate;
    if (data['issuedDate'] != null && data['issuedDate'] is firestore.Timestamp) {
      issuedDate = (data['issuedDate'] as firestore.Timestamp).toDate();
    } else {
      issuedDate = DateTime.now();
    }

    // Parse createdAt with fallback
    DateTime createdAt;
    if (data['createdAt'] != null && data['createdAt'] is firestore.Timestamp) {
      createdAt = (data['createdAt'] as firestore.Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    return EmploymentLetter(
      id: doc.id,
      templateId: data['templateId'] as String? ?? '',
      staffId: data['staffId'] as String? ?? '',
      staffName: data['staffName'] as String? ?? 'Unknown',
      staffPosition: data['staffPosition'] as String? ?? 'Unknown',
      staffDepartment: data['staffDepartment'] as String? ?? 'Unknown',
      customContent: data['customContent'] as String?,
      customFormatting: data['customFormatting'] != null
          ? LetterFormatting.fromMap(data['customFormatting'] as Map<String, dynamic>)
          : null,
      generatedPdfUrl: data['generatedPdfUrl'] as String?,
      issuedDate: issuedDate,
      issuedBy: data['issuedBy'] as String?,
      createdAt: createdAt,
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is firestore.Timestamp
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  EmploymentLetter copyWith({
    String? id,
    String? templateId,
    String? staffId,
    String? staffName,
    String? staffPosition,
    String? staffDepartment,
    String? customContent,
    LetterFormatting? customFormatting,
    String? generatedPdfUrl,
    DateTime? issuedDate,
    String? issuedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmploymentLetter(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      staffPosition: staffPosition ?? this.staffPosition,
      staffDepartment: staffDepartment ?? this.staffDepartment,
      customContent: customContent ?? this.customContent,
      customFormatting: customFormatting ?? this.customFormatting,
      generatedPdfUrl: generatedPdfUrl ?? this.generatedPdfUrl,
      issuedDate: issuedDate ?? this.issuedDate,
      issuedBy: issuedBy ?? this.issuedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
