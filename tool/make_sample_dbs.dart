import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final dir = Directory('sample_data');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final leftPath = 'sample_data/left.db';
  final rightPath = 'sample_data/right.db';

  for (final p in [leftPath, rightPath]) {
    final f = File(p);
    if (f.existsSync()) f.deleteSync();
  }

  final left = sqlite3.open(leftPath);
  left.execute('''
    CREATE TABLE employees (
      id INTEGER PRIMARY KEY,
      name TEXT,
      department TEXT,
      salary REAL
    );
  ''');
  final leftInsert = left.prepare(
    'INSERT INTO employees VALUES (?, ?, ?, ?)',
  );
  for (final row in [
    [1, 'Alice', 'Engineering', 90000],
    [2, 'Bob', 'Sales', 65000],
    [3, 'Carol', 'Engineering', 95000],
    [4, 'Dave', 'Marketing', 60000],
    [5, 'Eve', 'Engineering', 88000],
  ]) {
    leftInsert.execute(row);
  }
  leftInsert.dispose();
  left.dispose();

  final right = sqlite3.open(rightPath);
  right.execute('''
    CREATE TABLE employees (
      id INTEGER PRIMARY KEY,
      name TEXT,
      department TEXT,
      salary REAL
    );
  ''');
  final rightInsert = right.prepare(
    'INSERT INTO employees VALUES (?, ?, ?, ?)',
  );
  for (final row in [
    [1, 'Alice', 'Engineering', 92000], // salary differs
    [2, 'Bob', 'Sales', 65000], // identical
    [3, 'Carol', 'Engineering', 95000], // identical
    [4, 'Dave', 'Marketing', 62000], // salary differs
    [6, 'Frank', 'HR', 70000], // only in right
  ]) {
    rightInsert.execute(row);
  }
  rightInsert.dispose();
  right.dispose();

  print('Sample databases written to $leftPath and $rightPath');
}
