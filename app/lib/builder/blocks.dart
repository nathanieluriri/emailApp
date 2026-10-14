import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'blocks.g.dart';

enum BlockType { heading, text, button, image, divider, spacer, columns, social, footer }

const blockLabels = {
  BlockType.heading: 'Heading',
  BlockType.text: 'Text',
  BlockType.button: 'Button',
  BlockType.image: 'Image',
  BlockType.divider: 'Divider',
  BlockType.spacer: 'Spacer',
  BlockType.columns: '2 columns',
  BlockType.social: 'Social links',
  BlockType.footer: 'Footer',
};

const brandPalette = [
  '#4F378B',
  '#6750A4',
  '#D0BCFF',
  '#E8DEF8',
  '#1C1B1F',
  '#49454F',
  '#938F99',
  '#FFFFFF',
  '#21A366',
  '#F5C518',
  '#E8544A',
];

@JsonSerializable()
class Block {
  Block({String? id, required this.type, Map<String, dynamic>? props})
    : id = id ?? const Uuid().v4(),
      props = {...defaults(type), ...?props};

  final String id;
  final BlockType type;
  final Map<String, dynamic> props;

  String str(String key) => '${props[key] ?? ''}';
  num numOf(String key) => (props[key] as num?) ?? 0;

  Block copy() => Block(type: type, props: Map.of(props));

  static Map<String, dynamic> defaults(BlockType type) => switch (type) {
    BlockType.heading => {'text': 'A clear headline', 'fontSize': 26, 'color': '#1C1B1F', 'align': 'left', 'padding': 16},
    BlockType.text => {'text': 'Write something worth reading.', 'fontSize': 15, 'color': '#49454F', 'align': 'left', 'padding': 12},
    BlockType.button => {
      'text': 'Get started',
      'url': 'https://',
      'color': '#4F378B',
      'textColor': '#FFFFFF',
      'radius': 22,
      'align': 'left',
      'padding': 16,
      'fontSize': 15,
    },
    BlockType.image => {'src': '', 'alt': '', 'link': '', 'align': 'center', 'padding': 12, 'radius': 8},
    BlockType.divider => {'color': '#E2DDE6', 'padding': 16},
    BlockType.spacer => {'height': 24},
    BlockType.columns => {
      'left': 'Left column text.',
      'right': 'Right column text.',
      'fontSize': 15,
      'color': '#49454F',
      'align': 'left',
      'padding': 12,
    },
    BlockType.social => {
      'website': '',
      'linkedin': '',
      'x': '',
      'instagram': '',
      'facebook': '',
      'color': '#4F378B',
      'align': 'center',
      'padding': 12,
    },
    BlockType.footer => {
      'text': 'Bridgewood Investment, Lagos, Nigeria.\nYou are receiving this because you are in touch with us.',
      'fontSize': 12,
      'color': '#938F99',
      'align': 'center',
      'padding': 20,
    },
  };

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
  Map<String, dynamic> toJson() => _$BlockToJson(this);
}

String encodeBlocks(List<Block> blocks) => jsonEncode(blocks.map((b) => b.toJson()).toList());

List<Block> decodeBlocks(String? json) {
  if (json == null || json.isEmpty) return [];
  try {
    return (jsonDecode(json) as List).map((e) => Block.fromJson(Map<String, dynamic>.from(e))).toList();
  } catch (_) {
    return [];
  }
}
