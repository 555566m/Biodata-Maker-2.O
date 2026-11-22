import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appTitle = 'Biodata Maker 2.O';

void main() => runApp(MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7A1C3A),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE7DDE2)),
          ),
        ),
      ),
      home: const ModernBiodataHome(),
    ));

class ModernBiodataHome extends StatefulWidget {
  const ModernBiodataHome({super.key});
  @override
  State<ModernBiodataHome> createState() => _ModernBiodataHomeState();
}

class _ModernBiodataHomeState extends State<ModernBiodataHome> {
  String lang = 'English';
  int themeIdx = 0;
  String? photo;

  // Reorderable section keys (drag-and-drop or push up/down)
  final sectionOrder = [
    'personal',
    'family',
    'career',
    'contact',
    'lifestyle',
    'about',
  ];

  final sectionTitles = {
    'personal': 'Personal Details',
    'family': 'Family Details',
    'career': 'Education & Career',
    'contact': 'Contact Info',
    'lifestyle': 'Hobbies & Habits',
    'about': 'About & Expectations',
  };

  final c = {
    for (var k in [
      'name',
      'dob',
      'tob',
      'pob',
      'height',
      'weight',
      'complexion',
      'gotra',
      'father',
      'fatherOcc',
      'mother',
      'motherOcc',
      'siblings',
      'edu',
      'job',
      'income',
      'company',
      'mob1',
      'mob2',
      'email',
      'addr',
      'about',
      'expect',
    ])
      k: TextEditingController()
  };

  final extra = [];
  final tags = [];
  final chips = [
    'Reading',
    'Music',
    'Travel',
    'Vegetarian',
    'Non-Veg',
    'Never Smoke',
    'Never Drink',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _pushTile(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= sectionOrder.length) return;
    setState(() {
      final item = sectionOrder.removeAt(index);
      sectionOrder.insert(target, item);
    });
    _save();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'bm2o_modern_v1',
        jsonEncode({
          'lang': lang,
          'theme': themeIdx,
          'photo': photo,
          'order': sectionOrder,
          'tags': tags,
          'extra': extra,
          'f': {for (var e in c.entries) e.key: e.value.text},
        }));
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('bm2o_modern_v1');
    if (raw == null) return;
    final d = jsonDecode(raw);
    setState(() {
      lang = d['lang'] ?? 'English';
      themeIdx = d['theme'] ?? 0;
      photo = d['photo'];
      if (d['order'] != null) {
        final savedOrder = List.from(d['order']);
        if (savedOrder.length == sectionOrder.length &&
            sectionOrder.every((k) => savedOrder.contains(k))) {
          sectionOrder
            ..clear()
            ..addAll(savedOrder.map((e) => e.toString()));
        }
      }
      tags.clear();
      if (d['tags'] != null) tags.addAll(d['tags']);
      extra.clear();
      if (d['extra'] != null) extra.addAll(d['extra']);
      if (d['f'] != null) {
        d['f'].forEach((k, v) {
          if (c[k] != null) c[k]!.text = (v ?? '').toString();
        });
      }
    });
  }

  Future<Uint8List> _makePdf() async {
    final doc = pw.Document();
    final reg = await PdfGoogleFonts.notoSansDevanagariRegular();
    final bold = await PdfGoogleFonts.notoSansDevanagariBold();
    final col = themeIdx == 0
        ? PdfColor.fromHex('#7A1C3A')
        : themeIdx == 1
            ? PdfColor.fromHex('#9A6B1E')
            : PdfColor.fromHex('#154360');

    pw.Widget row(String k, String v) => v.trim().isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                    width: 125,
                    child: pw.Text(k,
                        style: pw.TextStyle(font: bold, fontSize: 10))),
                pw.Text(':  ',
                    style: pw.TextStyle(font: bold, fontSize: 10)),
                pw.Expanded(
                    child: pw.Text(v,
                        style: pw.TextStyle(font: reg, fontSize: 10))),
              ],
            ),
          );

    pw.Widget head(String t) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 9, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: col,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(t.toUpperCase(),
              style: pw.TextStyle(
                  font: bold, fontSize: 10.5, color: PdfColors.white)),
        );

    final img = (photo != null && File(photo!).existsSync())
        ? pw.MemoryImage(File(photo!).readAsBytesSync())
        : null;

    final dynamicBlocks = [];
    for (var key in sectionOrder) {
      if (key == 'personal') {
        dynamicBlocks.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    head('Personal Details'),
                    row('Full Name', c['name']!.text),
                    row('Date of Birth', c['dob']!.text),
                    row('Birth Time', c['tob']!.text),
                    row('Birth Place', c['pob']!.text),
                    row('Height / Weight',
                        '${c['height']!.text} | ${c['weight']!.text}'),
                    row('Complexion', c['complexion']!.text),
                    row('Gotra', c['gotra']!.text),
                  ],
                ),
              ),
              if (img != null)
                pw.Container(
                  width: 88,
                  height: 108,
                  margin: const pw.EdgeInsets.only(top: 9, left: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: col, width: 1.2),
                  ),
                  child: pw.Image(img, fit: pw.BoxFit.cover),
                ),
            ],
          ),
        );
      } else if (key == 'family') {
        dynamicBlocks.addAll([
          head('Family Details'),
          row('Father', '${c['father']!.text} (${c['fatherOcc']!.text})'),
          row('Mother', '${c['mother']!.text} (${c['motherOcc']!.text})'),
          row('Siblings', c['siblings']!.text),
        ]);
      } else if (key == 'career') {
        dynamicBlocks.addAll([
          head('Education & Career'),
          row('Qualification', c['edu']!.text),
          row('Occupation', c['job']!.text),
          row('Income / Company',
              '${c['income']!.text} | ${c['company']!.text}'),
        ]);
      } else if (key == 'contact') {
        dynamicBlocks.addAll([
          head('Contact Info'),
          row('Mobile 1', c['mob1']!.text),
          row('Mobile 2', c['mob2']!.text),
          row('Email', c['email']!.text),
          row('Address', c['addr']!.text),
        ]);
      } else if (key == 'lifestyle') {
        if (tags.isNotEmpty) {
          dynamicBlocks.addAll([
            head('Hobbies & Habits'),
            row('Selected', tags.join(', ')),
          ]);
        }
      } else if (key == 'about') {
        dynamicBlocks.addAll([
          head('About & Expectations'),
          row('About Me', c['about']!.text),
          row('Expectations', c['expect']!.text),
          for (var x in extra) row(x['k'].toString(), x['v'].toString()),
        ]);
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(22),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              'MARRIAGE BIODATA',
              style: pw.TextStyle(font: bold, fontSize: 18, color: col),
            ),
          ),
          pw.Divider(color: col, thickness: 1),
          ...dynamicBlocks,
        ],
      ),
    );
    return doc.save();
  }

  Widget _field(String k, String label, {TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c[k],
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFFAF7F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  Widget _sectionBody(String key) {
    if (key == 'personal') {
      return Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFF3E5EA),
            backgroundImage: photo != null ? FileImage(File(photo!)) : null,
            child: photo == null ? const Icon(Icons.person_outline, size: 30) : null,
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              final x = await ImagePicker()
                  .pickImage(source: ImageSource.gallery, imageQuality: 75);
              if (x != null) setState(() => photo = x.path);
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Select Photo'),
          ),
        ]),
        const SizedBox(height: 12),
        _field('name', 'Full Name'),
        _field('dob', 'Date of Birth'),
        _field('tob', 'Time of Birth'),
        _field('pob', 'Place of Birth'),
        _field('height', 'Height (e.g. 5 Ft 6 In)'),
        _field('weight', 'Weight (e.g. 65 KG)'),
        _field('complexion', 'Complexion'),
        _field('gotra', 'Gotra'),
      ]);
    }
    if (key == 'family') {
      return Column(children: [
        _field('father', "Father's Name"),
        _field('fatherOcc', "Father's Occupation"),
        _field('mother', "Mother's Name"),
        _field('motherOcc', "Mother's Occupation"),
        _field('siblings', 'Brothers / Sisters'),
      ]);
    }
    if (key == 'career') {
      return Column(children: [
        _field('edu', 'Qualification'),
        _field('job', 'Occupation'),
        _field('income', 'Annual Income'),
        _field('company', 'Organization / Company'),
      ]);
    }
    if (key == 'contact') {
      return Column(children: [
        _field('mob1', 'Primary Mobile', type: TextInputType.phone),
        _field('mob2', 'Alternate Mobile', type: TextInputType.phone),
        _field('email', 'Email ID', type: TextInputType.emailAddress),
        _field('addr', 'Residential Address'),
      ]);
    }
    if (key == 'lifestyle') {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips
            .map((t) => FilterChip(
                  label: Text(t),
                  selected: tags.contains(t),
                  onSelected: (on) =>
                      setState(() => on ? tags.add(t) : tags.remove(t)),
                ))
            .toList(),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field('about', 'About Me'),
      _field('expect', 'Partner Expectations'),
      for (var i = 0; i < extra.length; i++)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${extra[i]['k']}: ${extra[i]['v']}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => setState(() => extra.removeAt(i)),
          ),
        ),
      TextButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Add Custom Field'),
        onPressed: () {
          final k = TextEditingController(), v = TextEditingController();
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Custom Field'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: k,
                          decoration:
                              const InputDecoration(labelText: 'Field Name')),
                      TextField(
                          controller: v,
                          decoration: const InputDecoration(labelText: 'Value')),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () {
                          if (k.text.trim().isNotEmpty &&
                              v.text.trim().isNotEmpty) {
                            setState(() =>
                                extra.add({'k': k.text.trim(), 'v': v.text.trim()}));
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ));
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2F4),
      appBar: AppBar(
        title: const Text(appTitle, style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Save Draft',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              await _save();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Draft saved!')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top compact control strip (Language + Theme)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    value: lang,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'English',
                      'हिन्दी',
                      'मराठी',
                      'ગુજરાતી',
                      'বাংলা',
                      'தமிழ்',
                      'తెలుగు',
                      'ಕನ್ನಡ',
                    ]
                        .map((e) =>
                            DropdownMenuItem<String>(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => lang = v ?? 'English'),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 0, label: Text('Maroon')),
                      ButtonSegment<int>(value: 1, label: Text('Gold')),
                      ButtonSegment<int>(value: 2, label: Text('Blue')),
                    ],
                    selected: {themeIdx},
                    onSelectionChanged: (s) => setState(() => themeIdx = s.first),
                  ),
                ]),
              ),
            ),
          ),

          // Drag & Drop + Push Up/Down Reorderable Tiles
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 84),
              itemCount: sectionOrder.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = sectionOrder.removeAt(oldIndex);
                  sectionOrder.insert(newIndex, moved);
                });
                _save();
              },
              itemBuilder: (context, index) {
                final key = sectionOrder[index];
                return Card(
                  key: ValueKey(key),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(
                      sectionTitles[key] ?? key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Push Up',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: index == 0 ? null : () => _pushTile(index, -1),
                        ),
                        IconButton(
                          tooltip: 'Push Down',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: index == sectionOrder.length - 1
                              ? null
                              : () => _pushTile(index, 1),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                        child: _sectionBody(key),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text(
              'Preview & Share PDF',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              await _save();
              final bytes = await _makePdf();
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Biodata Preview'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () async {
                            final f = File(
                                '${Directory.systemTemp.path}/Biodata_Maker_2O.pdf');
                            await f.writeAsBytes(bytes);
                            await Share.shareXFiles([XFile(f.path)]);
                          },
                        ),
                      ],
                    ),
                    body: PdfPreview(
                      build: (_) async => bytes,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
