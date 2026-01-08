// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'petty_cash_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PettyCashReportAdapter extends TypeAdapter<PettyCashReport> {
  @override
  final int typeId = 1;

  @override
  PettyCashReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PettyCashReport(
      id: fields[0] as String,
      reportNumber: fields[1] as String,
      periodStart: fields[2] as DateTime,
      periodEnd: fields[3] as DateTime,
      department: fields[4] as String,
      custodianId: fields[5] as String,
      custodianName: fields[6] as String,
      openingBalance: fields[7] as double,
      closingBalance: fields[8] as double,
      totalDisbursements: fields[9] as double,
      cashOnHand: fields[10] as double,
      variance: fields[11] as double,
      transactionIds: (fields[13] as List?)?.cast<String>(),
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime?,
      companyName: fields[16] as String?,
      notes: fields[17] as String?,
    )..statusIndex = fields[12] as String;
  }

  @override
  void write(BinaryWriter writer, PettyCashReport obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportNumber)
      ..writeByte(2)
      ..write(obj.periodStart)
      ..writeByte(3)
      ..write(obj.periodEnd)
      ..writeByte(4)
      ..write(obj.department)
      ..writeByte(5)
      ..write(obj.custodianId)
      ..writeByte(6)
      ..write(obj.custodianName)
      ..writeByte(7)
      ..write(obj.openingBalance)
      ..writeByte(8)
      ..write(obj.closingBalance)
      ..writeByte(9)
      ..write(obj.totalDisbursements)
      ..writeByte(10)
      ..write(obj.cashOnHand)
      ..writeByte(11)
      ..write(obj.variance)
      ..writeByte(12)
      ..write(obj.statusIndex)
      ..writeByte(13)
      ..write(obj.transactionIds)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt)
      ..writeByte(16)
      ..write(obj.companyName)
      ..writeByte(17)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PettyCashReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
