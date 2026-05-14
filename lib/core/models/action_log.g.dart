// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ActionLogAdapter extends TypeAdapter<ActionLog> {
  @override
  final int typeId = 2;

  @override
  ActionLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActionLog(
      id: fields[0] as String,
      intentType: fields[1] as String,
      description: fields[2] as String,
      isSuccess: fields[3] as bool,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ActionLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.intentType)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isSuccess)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
