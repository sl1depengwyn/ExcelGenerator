import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';

var months = [
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Сентябрь следующего года',
  'Итого',
  'Доп. оплаты'
];

var columns = ['Кол. Чел', 'Ф. И.', 'Дата начала занятий'] + months;

String currentName = '';

var _usersOnMachine = <User>[User()];
var numberOfDeletedUsers = 0;
const _title = 'ExcelGenerator';

Future<void> main() async {
  runApp(const LoadingScreen());
  await getState();
  runApp(const MyApp());
}

Future<void> getState() async {
  Directory tempDir = await getApplicationSupportDirectory();
  var file = File('${tempDir.path}\\excel_generator_state.json');
  if (file.existsSync()) {
    var json = jsonDecode(file.readAsStringSync());
    _usersOnMachine =
        (json['users'] as List).map((user) => User.fromJson(user)).toList();
    for (var user in _usersOnMachine) {
      if (user.toRemove) {
        ++numberOfDeletedUsers;
      }
    }
    currentName = json['name'];
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: _title,
        theme: ThemeData(
          primarySwatch: Colors.cyan,
        ),
        home: Scaffold(
            appBar: AppBar(
              title: const Text(_title),
              actions: [
                IconButton(icon: const Icon(Icons.save), onPressed: () {}),
              ],
            ),
            body: const Center(
              child: ScaffoldMessenger(child: Text('Loading...')),
            )));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      theme: ThemeData(
        primarySwatch: Colors.cyan,
      ),
      home: const MyHomePage(title: _title),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  var _users = _usersOnMachine;
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _saveState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Future<void> _saveState() async {
    Directory tempDir = await getApplicationSupportDirectory();
    var file = File('${tempDir.path}\\excel_generator_state.json');
    var json = jsonEncode({'name': currentName, 'users': _users});
    file.writeAsString(json);
  }

  void _addUser() {
    if (_users[_users.length - 1 - numberOfDeletedUsers].name != '' &&
        _users[_users.length - 1 - numberOfDeletedUsers].dateStartOfEducation !=
            '') {
        _users.add(User());
        _users.sort((a, b) {
          if (a.toRemove == b.toRemove) return 0;
          if (!a.toRemove) return -1;
          return 1;
        });
      }
    }


  void _removeUser(User user) {
    if (!user.toRemove) {
      ++numberOfDeletedUsers;
        user.changeRemove();
        _users.remove(user);
        _users.add(user);
    }
  }

  Future<void> _pushSave() async {
    _saveState();
    var excel = Excel.createExcel();
    excel.rename('Sheet1', currentName);
    var sheet = excel[currentName];
    for (int i = 0; i < columns.length; ++i) {
      var cellStyle = CellStyle(
          bold: true, fontSize: 10, textWrapping: TextWrapping.WrapText);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), columns[i],
          cellStyle: cellStyle);
    }
    int row = 1;
    for (User user in _users) {
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), row);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), user.name);
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
          user.dateStartOfEducation);
      int column = 3;
      for (int paid in user.paid) {
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            paid);
        column++;
      }
      row++;
    }
    for (int i = 0; i < months.length; ++i) {
      num value = 0;
      for (var user in _users) {
        value += user.paid[i] ?? 0;
      }
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: i + 3, rowIndex: row),
          value.toInt(),
          cellStyle: CellStyle(backgroundColorHex: '#3792cb'));
    }
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    //saveExcel(excel, 'D:\\excelGenerator\\Отчет ' + formattedDate + '.xlsx');
    final name = "Отчет $currentName $formattedDate.xlsx";
    final data = Uint8List.fromList(excel.encode()!);
    if (Platform.isWindows) {
      final path = await getSavePath(suggestedName: name, acceptedTypeGroups: [
        XTypeGroup(label: 'Excel', extensions: ['xlsx'])
      ]);
      const mimeType = "application/vnd.ms-excel";
      final file = XFile.fromData(data, name: name, mimeType: mimeType);
      await file.saveTo(path);
    } else if (Platform.isAndroid) {
      final params = SaveFileDialogParams(data: data, fileName: name);
      final filePath = await FlutterFileDialog.saveFile(params: params);
    }
  }

  void _debugDeleteAll() {
    _users = <User>[User()];
    _users[0].name = '';
    _users[0].dateStartOfEducation = '';
    numberOfDeletedUsers = 0;
    setState(() {});
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextFormField(
          key: Key(currentName),
          initialValue: currentName,
          decoration:
              const InputDecoration(hintText: "Введите название филиала"),
          onChanged: (val) {
            currentName = val;
          },
          onTap: () {
            if (Platform.isWindows) {
              _saveState();
            }
          },
        ),
        actions: [
          IconButton(
              onPressed: _debugDeleteAll,
              icon: const Icon(Icons.delete_forever_outlined)),
          IconButton(onPressed: _pushSave, icon: const Icon(Icons.save))
        ],
      ),
      body: _getBodyWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _addUser();
          });
        },
        tooltip: 'Добавить пользователя',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _getBodyWidget() {
    return SizedBox(
      child: HorizontalDataTable(
          leftHandSideColumnWidth: 150,
          rightHandSideColumnWidth: 1620,
          isFixedHeader: true,
          headerWidgets: _buildColumns(),
          leftSideChildren: _users.map((user) => _generateFirstColumnRow(user)).toList(),
          rightSideChildren: _users.map((user) => _generateRightHandSideColumnRow(user)).toList(),
          itemCount: _users.length,
          horizontalScrollbarStyle: const ScrollbarStyle(
            isAlwaysShown: true,
            thickness: 5.0,
            radius: Radius.circular(5.0),
          )),
      height: MediaQuery.of(context).size.height,
    );
  }

  List<Widget> _buildColumns() {
    const _columnTextStyle =
        TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
    var _columns = <Widget>[];
    _columns.add(Container(
        child: const Text('Ф.И.', style: _columnTextStyle),
        width: 150,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    _columns.add(Container(
        child: const Text('Дата начала занятий', style: _columnTextStyle),
        width: 200,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    for (var i = 0; i < months.length; i++) {
      _columns.add(Container(
          child: Text(months[i], style: _columnTextStyle),
          width: i == months.length - 3 ? 220 : 100,
          height: 52,
          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
          alignment: Alignment.centerLeft));
    }
    _columns.add(Container(
        child: const Text(''),
        width: 100,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft));
    return _columns;
  }

  Widget _generateFirstColumnRow(user) {
    var _key = Key(user.name + user.dateStartOfEducation);
    return Container(
      child: TextFormField(
        key: _key,
        readOnly: user.toRemove,
        initialValue: user.name,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp("[0-9]+"))],
        maxLength: 60,
        decoration:
            const InputDecoration(hintText: "Введите Ф.И", counterText: ""),
        keyboardType: TextInputType.text,
        onChanged: (val) {
          user.name = val;
        },
        onTap: () {
          if (Platform.isWindows) {
            _saveState();
          }
        },
      ),
      width: 150,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
      color: user.toRemove ? Colors.deepOrange : Colors.transparent,
    );
  }

  Widget _generateRightHandSideColumnRow(user) {
    var _key = Key(user.name + user.dateStartOfEducation);
    var _cells = LinkedHashMap<String, Widget>();
    var _color =
    user.toRemove ? Colors.deepOrange : Colors.transparent;
    _cells['date'] = Container(
      child: TextFormField(
        key: _key,
        readOnly: user.toRemove,
        initialValue: user.dateStartOfEducation,
        decoration: const InputDecoration(hintText: "Введите дату"),
        keyboardType: TextInputType.datetime,
        onChanged: (val) {
          user.dateStartOfEducation = val;
        },
        onTap: () {
          if (Platform.isWindows) {
            _saveState();
          }
        },
      ),
      width: 200,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );
    for (var i = 0; i < months.length; ++i) {
      _cells[months[i]] = Container(
        child: TextFormField(
            key: _key,
            readOnly: user.toRemove,
            keyboardType: TextInputType.number,
            initialValue: user.paid[i] == null
                ? ''
                : user.paid[i].toString(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[0-9]+"))
            ],
            onChanged: (val) {
              user.paid[i] = val == '' ? 0 : int.parse(val);
              user.calculateResult();
              setState(() {});
            },
            onTap: () {
              if (Platform.isWindows) {
                _saveState();
              }
            }),
        width: i == months.length - 3 ? 220 : 100,
        height: 52,
        padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
        alignment: Alignment.centerLeft,
      );
    }
    _cells['Итого'] = Container(
      child: Text(user.result.toString()),
      width: 100,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );
    _cells['remove'] = Container(
      child: IconButton(
          onPressed: () {
            _removeUser(user);
            setState(() {});
            if (Platform.isWindows) _saveState();
          },
          icon: const Icon(Icons.delete, size: 20)),
      width: 100,
      height: 52,
      padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
      alignment: Alignment.centerLeft,
    );
    return Container(
        child: Row(children: _cells.values.toList()), color: _color);
  }
}

class User {
  late String name;
  late String dateStartOfEducation;
  late List<dynamic> paid;
  late num result;
  bool toRemove = false;

  void calculateResult() {
    paid[paid.length - 2] = 0;
    result = 0;
    for (var el in paid) {
      result += el ?? 0;
    }
    paid[paid.length - 2] = result;
  }

  void changeRemove() {
    toRemove = !toRemove;
  }

  Map toJson() => {
        'name': name,
        'dateStartOfEducation': dateStartOfEducation,
        'paid': paid,
        'result': result,
        'toRemove': toRemove
      };

  factory User.fromJson(dynamic json) {
    return User.allData(
        json['name'] as String,
        json['dateStartOfEducation'] as String,
        json['paid'].cast<int>(),
        json['result'] as int,
        json['toRemove'] as bool);
  }

  User() {
    result = 0;
    name = '';
    dateStartOfEducation = '';
    paid = List.filled(months.length, null, growable: false);
  }

  User.byName(String name) {
    this.name = name;
    paid = List.filled(months.length, null, growable: false);
  }

  User.allData(this.name, this.dateStartOfEducation, this.paid, this.result,
      this.toRemove);
}

// TODO:
// 1. сделать кнопку сохранить для строки или автоматом как-нибудь все это дело чтобы сохранялось              - done
// 1.1 разобраться с сабмитом этих форм которые в строке                                                       - done
// 2. экспорт xlsx:                                                                                            - done
// 2.1. базовый экспорт: разобраться с либой, выводить просто строчки                                          - done
// 2.2. разобраться со стилями, чтобы все красиво +- как в примере выводилось                                  - done
// 3. добавить автоподсчет ИТОГО                                                                               - done
// 4. настроить логику удаления (как в скринах) (чтобы падала вниз и раскрашивалась строчка)                   - done
// 5. если делать будет нечего, то заняться тем, чтобы убрать хардкод в моменте наполненния колонок для строки - done
// 6. добавить ввод для названия филиала                                                                       - done
// 7. добавить сохранение текущего стейта, чтобы данные не терялись при закрытии                               - done (можно попытаться ловить закрытие на винде)
// 8. сохранение xlsx на андроиде                                                                              - done
