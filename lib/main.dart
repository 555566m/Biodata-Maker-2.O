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

const titleApp = 'Biodata Maker 2.O';
void main() => runApp(MaterialApp(
      title: titleApp,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8B1E3F), useMaterial3: true),
      home: const BiodataApp(),
    ));

class BiodataApp extends StatefulWidget {
  const BiodataApp({super.key});
  @override
  State<BiodataApp> createState() => _BiodataAppState();
}

class _BiodataAppState extends State<BiodataApp> {
  String lang = 'English', rel1 = 'Self', rel2 = 'Father';
  String? photo;
  int themeIdx = 0;
  final c = {
    for (var k in [
      'name','dob','tob','pob','height','weight','complexion','gotra',
      'father','fatherOcc','mother','motherOcc','siblings',
      'edu','job','income','company','mob1','mob2','email','addr','about','expect'
    ]) k: TextEditingController()
  };
  final extra = [];
  final tags = [];
  final chips = ['Reading','Music','Travel','Vegetarian','Non-Veg','Never Smoke','Never Drink'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('bm2o_data', jsonEncode({
      'lang': lang, 'theme': themeIdx, 'photo': photo, 'r1': rel1, 'r2': rel2,
      'tags': tags, 'extra': extra,
      'f': {for (var e in c.entries) e.key: e.value.text},
    }));
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('bm2o_data');
    if (raw == null) return;
    final d = jsonDecode(raw);
    setState(() {
      lang = d['lang'] ?? 'English';
      themeIdx = d['theme'] ?? 0;
      photo = d['photo'];
      rel1 = d['r1'] ?? 'Self';
      rel2 = d['r2'] ?? 'Father';
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
        ? PdfColor.fromHex('#8B1E3F')
        : themeIdx == 1
            ? PdfColor.fromHex('#9A6B1E')
            : PdfColor.fromHex('#1B4965');
    pw.Widget line(String k, String v) => v.trim().isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.SizedBox(width: 120, child: pw.Text(k, style: pw.TextStyle(font: bold, fontSize: 10))),
              pw.Text(': ', style: pw.TextStyle(font: bold, fontSize: 10)),
              pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: reg, fontSize: 10))),
            ]),
          );
    pw.Widget head(String t) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: col,
          child: pw.Text(t, style: pw.TextStyle(font: bold, fontSize: 11, color: PdfColors.white)),
        );
    final img = (photo != null && File(photo!).existsSync())
        ? pw.MemoryImage(File(photo!).readAsBytesSync())
        : null;
    doc.addPage(pw.MultiPage(build: (_) => [
          pw.Center(child: pw.Text('MARRIAGE BIODATA', style: pw.TextStyle(font: bold, fontSize: 17, color: col))),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              head('PERSONAL DETAILS'),
              line('Full Name', c['name']!.text),
              line('Date of Birth', c['dob']!.text),
              line('Birth Time', c['tob']!.text),
              line('Birth Place', c['pob']!.text),
              line('Height / Weight', '${c['height']!.text} | ${c['weight']!.text}'),
              line('Complexion', c['complexion']!.text),
              line('Gotra', c['gotra']!.text),
            ])),
            if (img != null)
              pw.Container(
                  width: 88,
                  height: 108,
                  margin: const pw.EdgeInsets.only(top: 8, left: 10),
                  child: pw.Image(img, fit: pw.BoxFit.cover)),
          ]),
          head('FAMILY DETAILS'),
          line('Father', '${c['father']!.text} (${c['fatherOcc']!.text})'),
          line('Mother', '${c['mother']!.text} (${c['motherOcc']!.text})'),
          line('Siblings', c['siblings']!.text),
          head('EDUCATION & JOB'),
          line('Qualification', c['edu']!.text),
          line('Occupation', c['job']!.text),
          line('Income / Company', '${c['income']!.text} | ${c['company']!.text}'),
          head('CONTACT & ABOUT'),
          line('Mobile ($rel1)', c['mob1']!.text),
          line('Mobile ($rel2)', c['mob2']!.text),
          line('Email', c['email']!.text),
          line('Address', c['addr']!.text),
          if (tags.isNotEmpty) line('Lifestyle', tags.join(', ')),
          line('About Me', c['about']!.text),
          line('Expectations', c['expect']!.text),
          for (var x in extra) line(x['k'].toString(), x['v'].toString()),
        ]));
    return doc.save();
  }

  Widget inp(String k, String l, {TextInputType? t}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
            controller: c[k],
            keyboardType: t,
            decoration: InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder())),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(titleApp), actions: [
          IconButton(
              icon: const Icon(Icons.save),
              onPressed: () async {
                await _save();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
              }),
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          DropdownButtonFormField<String>(
            value: lang,
            decoration: const InputDecoration(labelText: 'Language', isDense: true, border: OutlineInputBorder()),
            items: ['English', 'हिन्दी', 'मराठी', 'ગુજરાતી', 'বাংলা', 'தமிழ்', 'తెలుగు', 'ಕನ್ನಡ']
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
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
          const SizedBox(height: 8),
          Row(children: [
            CircleAvatar(
                radius: 28,
                backgroundImage: photo != null ? FileImage(File(photo!)) : null,
                child: photo == null ? const Icon(Icons.person) : null),
            const SizedBox(width: 10),
            ElevatedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                  if (x != null) setState(() => photo = x.path);
                },
                icon: const Icon(Icons.photo),
                label: const Text('Photo')),
          ]),
          const SizedBox(height: 8),
          inp('name', 'Full Name'),
          inp('dob', 'Date of Birth'),
          inp('tob', 'Time of Birth'),
          inp('pob', 'Place of Birth'),
          inp('height', 'Height (e.g. 5 Ft 6 In)'),
          inp('weight', 'Weight (e.g. 65 KG)'),
          inp('complexion', 'Complexion'),
          inp('gotra', 'Gotra'),
          inp('father', "Father's Name"),
          inp('fatherOcc', "Father's Occupation"),
          inp('mother', "Mother's Name"),
          inp('motherOcc', "Mother's Occupation"),
          inp('siblings', 'Brothers / Sisters'),
          inp('edu', 'Qualification'),
          inp('job', 'Occupation'),
          inp('income', 'Annual Income'),
          inp('company', 'Company'),
          inp('mob1', 'Mobile 1', t: TextInputType.phone),
          inp('mob2', 'Mobile 2', t: TextInputType.phone),
          inp('email', 'Email', t: TextInputType.emailAddress),
          inp('addr', 'Address'),
          Wrap(
              spacing: 6,
              children: chips
                  .map((t) => FilterChip(
                      label: Text(t),
                      selected: tags.contains(t),
                      onSelected: (on) => setState(() => on ? tags.add(t) : tags.remove(t))))
                  .toList()),
          const SizedBox(height: 8),
          inp('about', 'About Me'),
          inp('expect', 'Expectations'),
          for (var i = 0; i < extra.length; i++)
            ListTile(
                dense: true,
                title: Text('${extra[i]['k']}: ${extra[i]['v']}'),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => extra.removeAt(i)))),
          TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Field'),
              onPressed: () {
                final k = TextEditingController(), v = TextEditingController();
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title: const Text('Custom Field'),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            TextField(controller: k, decoration: const InputDecoration(labelText: 'Field Name')),
                            TextField(controller: v, decoration: const InputDecoration(labelText: 'Value')),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                                onPressed: () {
                                  if (k.text.trim().isNotEmpty && v.text.trim().isNotEmpty) {
                                    setState(() => extra.add({'k': k.text.trim(), 'v': v.text.trim()}));
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Add')),
                          ],
                        ));
              }),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Preview & Share PDF'),
            onPressed: () async {
              await _save();
              final bytes = await _makePdf();
              if (!mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Biodata Preview'), actions: [
                              IconButton(
                                  icon: const Icon(Icons.share),
                                  onPressed: () async {
                                    final f = File('${Directory.systemTemp.path}/Biodata_Maker_2O.pdf');
                                    await f.writeAsBytes(bytes);
                                    await Share.shareXFiles([XFile(f.path)]);
                                  }),
                            ]),
                            body: PdfPreview(
                                build: (_) async => bytes, canChangePageFormat: false, canChangeOrientation: false),
                          )));
            },
          ),
        ]),
      );
}
