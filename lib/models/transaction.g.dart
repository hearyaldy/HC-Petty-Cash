// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 2;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      reportId: fields[1] as String,
      date: fields[2] as DateTime,
      receiptNo: fields[3] as String,
      description: fields[4] as String,
      amount: fields[6] as double,
      requestorId: fields[8] as String,
      approverId: fields[9] as String?,
      attachments: (fields[11] as List?)?.cast<String>(),
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime?,
      paidTo: fields[15] as String?,
    )
      ..categoryIndex = fields[5] as String
      ..paymentMethodIndex = fields[7] as String
      ..statusIndex = fields[10] as String
      ..approvalHistoryJson = (fields[12] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList();
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.receiptNo)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.categoryIndex)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.paymentMethodIndex)
      ..writeByte(8)
      ..write(obj.requestorId)
      ..writeByte(9)
      ..write(obj.approverId)
      ..writeByte(10)
      ..write(obj.statusIndex)
      ..writeByte(11)
      ..write(obj.attachments)
      ..writeByte(12)
      ..write(obj.approvalHistoryJson)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.paidTo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
