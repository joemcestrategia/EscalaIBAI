import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Ministerio {
  final String nome;
  final String? icone;

  const Ministerio({
    required this.nome,
    this.icone,
  });

  IconData get iconData {
    if (icone == null) return PhosphorIconsBold.usersThree;
    return availableIcons[icone] ?? PhosphorIconsBold.usersThree;
  }

  static const Map<String, IconData> availableIcons = {
    'music': PhosphorIconsBold.musicNotes,
    'microphone': PhosphorIconsBold.microphone,
    'video': PhosphorIconsBold.videoCamera,
    'monitor': PhosphorIconsBold.monitor,
    'heart': PhosphorIconsBold.heart,
    'baby': PhosphorIconsBold.baby,
    'book': PhosphorIconsBold.bookOpen,
    'church': PhosphorIconsBold.church,
    'users': PhosphorIconsBold.usersThree,
    'briefcase': PhosphorIconsBold.briefcase,
    'megaphone': PhosphorIconsBold.megaphone,
    'calendar': PhosphorIconsBold.calendar,
    'camera': PhosphorIconsBold.camera,
    'shield': PhosphorIconsBold.shield,
    'coffee': PhosphorIconsBold.coffee,
    'firstAid': PhosphorIconsBold.firstAid,
    'graduationCap': PhosphorIconsBold.graduationCap,
    'handHeart': PhosphorIconsBold.handHeart,
    'house': PhosphorIconsBold.house,
    'leaf': PhosphorIconsBold.leaf,
    'lightbulb': PhosphorIconsBold.lightbulb,
    'mapPin': PhosphorIconsBold.mapPin,
    'palette': PhosphorIconsBold.palette,
    'phone': PhosphorIconsBold.phone,
    'smiley': PhosphorIconsBold.smiley,
    'star': PhosphorIconsBold.star,
    'ticket': PhosphorIconsBold.ticket,
    'trophy': PhosphorIconsBold.trophy,
  };

  factory Ministerio.fromMap(Map<String, dynamic> map) => Ministerio(
        nome: map['nome'] as String,
        icone: map['icone'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'icone': icone,
      };
}
