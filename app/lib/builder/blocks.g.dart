// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocks.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Block _$BlockFromJson(Map<String, dynamic> json) =>
    Block(id: json['id'] as String?, type: $enumDecode(_$BlockTypeEnumMap, json['type']), props: json['props'] as Map<String, dynamic>?);

Map<String, dynamic> _$BlockToJson(Block instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$BlockTypeEnumMap[instance.type]!,
  'props': instance.props,
};

const _$BlockTypeEnumMap = {
  BlockType.heading: 'heading',
  BlockType.text: 'text',
  BlockType.button: 'button',
  BlockType.image: 'image',
  BlockType.divider: 'divider',
  BlockType.spacer: 'spacer',
  BlockType.columns: 'columns',
  BlockType.social: 'social',
  BlockType.footer: 'footer',
};
