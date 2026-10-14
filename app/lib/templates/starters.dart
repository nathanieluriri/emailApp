import '../builder/blocks.dart';
import '../builder/html_export.dart';
import 'template.dart';
import 'variables.dart';

Block _b(BlockType type, [Map<String, dynamic>? props]) => Block(type: type, props: props);

MailTemplate _starter(String id, String name, String subject, List<Block> blocks) {
  final html = exportBlocks(blocks);
  return MailTemplate(
    id: 'starter-$id',
    name: name,
    subject: subject,
    html: html,
    blocksJson: encodeBlocks(blocks),
    variables: findVariables([subject, html]),
  );
}

final starterTemplates = [
  _starter('welcome', 'Welcome', 'Welcome to Bridgewood, {{first_name}}', [
    _b(BlockType.heading, {'text': 'Welcome aboard, {{first_name}}', 'fontSize': 28}),
    _b(BlockType.text, {
      'text': 'We are glad {{company}} chose Bridgewood Investment. Your account is ready, and your relationship manager will reach out within one business day.',
    }),
    _b(BlockType.button, {'text': 'Open your dashboard', 'url': 'https://bridgewoodinvestment.ng'}),
    _b(BlockType.divider),
    _b(BlockType.text, {'text': 'Questions? Reply to this email and a real person will answer.', 'fontSize': 13}),
    _b(BlockType.footer),
  ]),
  _starter('invoice', 'Invoice / Receipt', 'Receipt for {{amount}}', [
    _b(BlockType.heading, {'text': 'Payment received', 'fontSize': 24}),
    _b(BlockType.text, {'text': 'Hi {{first_name}}, thank you. We have received your payment.'}),
    _b(BlockType.columns, {'left': 'Amount\nReference\nDate', 'right': '{{amount}}\n{{reference}}\n{{date}}', 'color': '#1C1B1F'}),
    _b(BlockType.divider),
    _b(BlockType.button, {'text': 'Download receipt', 'url': 'https://', 'color': '#21A366'}),
    _b(BlockType.footer, {'text': 'Bridgewood Investment. Keep this email for your records.'}),
  ]),
  _starter('announcement', 'Announcement', 'News from Bridgewood: {{headline}}', [
    _b(BlockType.image, {'src': '', 'alt': 'Announcement'}),
    _b(BlockType.heading, {'text': '{{headline}}', 'align': 'center', 'fontSize': 30}),
    _b(BlockType.text, {'text': 'Something new is here, and we wanted you to hear it first.', 'align': 'center'}),
    _b(BlockType.button, {'text': 'Read the details', 'align': 'center'}),
    _b(BlockType.social, {'website': 'https://bridgewoodinvestment.ng'}),
    _b(BlockType.footer),
  ]),
  _starter('newsletter', 'Newsletter', 'Bridgewood Monthly: {{month}}', [
    _b(BlockType.heading, {'text': 'Bridgewood Monthly', 'color': '#4F378B'}),
    _b(BlockType.text, {'text': 'Hi {{first_name}}, here is what moved this month.'}),
    _b(BlockType.divider),
    _b(BlockType.heading, {'text': 'Market notes', 'fontSize': 18}),
    _b(BlockType.columns, {
      'left': 'Equities held steady while fixed income yields rose.',
      'right': 'Our outlook for next quarter stays cautious and long term.',
    }),
    _b(BlockType.button, {'text': 'Read the full issue'}),
    _b(BlockType.social, {'website': 'https://bridgewoodinvestment.ng', 'linkedin': 'https://linkedin.com'}),
    _b(BlockType.footer),
  ]),
  _starter('follow-up', 'Follow-up', 'Following up, {{first_name}}', [
    _b(BlockType.text, {
      'text': 'Hi {{first_name}},\n\nI wanted to follow up on our conversation about {{topic}}. Do you have 15 minutes this week to go over next steps?\n\nBest regards,',
    }),
  ]),
  _starter('plain', 'Plain professional', '{{subject}}', [
    _b(BlockType.text, {'text': 'Dear {{first_name}},\n\n\n\nKind regards,', 'color': '#1C1B1F'}),
  ]),
];
