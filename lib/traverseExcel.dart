// ignore_for_file: public_member_api_docs, sort_constructors_first
// import 'package:excel/excel.dart';
// import 'package:file_picker/file_picker.dart';

// class ExcelSheetUploader {
//   Future<List<List<Map<String, dynamic>>>> uploadAndParse() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       allowMultiple: false,
//       type: FileType.custom,
//       allowedExtensions: ['xlsx'],
//       withData: true,
//     );

//     if (result == null) {
//       throw Exception('File picking was canceled.');
//     }

//     var bytes = result.files.first.bytes!;
//     var excel = Excel.decodeBytes(bytes);
//     print('excel');
//     List<List<Map<String, dynamic>>> sheetsData = [];

//     for (var sheet in excel.tables.keys) {
//       sheetsData.add(_traverseExcelData(excel.tables[sheet]!));
//     }
//     return sheetsData;
//   }

//   List<Map<String, dynamic>> _traverseExcelData(Sheet sheet) {
//     List<Map<String, dynamic>> jsonData = [];

//     if (sheet.maxRows == 0) {
//       return jsonData;
//     }

//     var headers = sheet
//         .row(0)
//         .map((cell) => cell?.value?.toString().trim() ?? '')
//         .toList();
//     print('headers: $headers');

//     for (var i = 1; i < sheet.maxRows; i++) {
//       Map<String, dynamic> rowMap = {};
//       if (sheet.rows[i]
//           .every((cell) => cell?.value?.toString().trim().isEmpty ?? true)) {
//         break;
//       }

//       for (var j = 0; j < sheet.maxColumns; j++) {
//         var header = headers[j];
//         var cellValue = sheet.row(i)[j]?.value?.toString().trim() ?? '';
//         rowMap[header] = cellValue;
//       }

//       jsonData.add(rowMap);
//       print('rowMap: $rowMap');
//     }

//     return jsonData;
//   }
// }
//?
// Future<void> uploadToStaffSubjectAllocation({
//   required CollectionReference collectionRef,
//   required String schoolId,
//   required List<Map<String, dynamic>> dataList,
// }) async {
//   // print('data$dataList');
//   CollectionReference staffCollectionReference =
//       FirebaseFirestore.instance.collection('Staff');
//   try {
//     for (var staff in dataList) {
//       String tName = staff['staff_name'];
//       String grade = staff['grade'];
//       String sections = staff['sections'];
//       String subjects = staff['subject_name'];
//       List<String> sectionList = sections.split(',');
//       List<String> subjectList = subjects.split(',');

//       List<Map<String, String>> result = [];
//       Map<String, String> subjectAllocation = {};

//       for (String section in sectionList) {
//         for (String subject in subjectList) {
//           result.add({
//             'grade': grade,
//             'section': section.trim(),
//             'subjectname': subject.trim()
//           });
//           subjectAllocation['grade'] = grade;
//           subjectAllocation['section'] = section.trim();
//           subjectAllocation['subjectname'] = subject.trim();
//           subjectAllocation['tName'] = tName;
//           subjectAllocation['tid'] = grade;
//           // print('subjectAllocation $subjectAllocation'); //!
//           collectionRef
//               .doc(schoolId)
//               .collection('SubjectAllocation')
//               .doc()
//               .set(subjectAllocation);
//         }
//       }
//       // print('Result for $tName: $result');
//       QuerySnapshot querySnapshot = await staffCollectionReference
//           .where('schoolID', isEqualTo: collectionRef.doc(schoolId))
//           .where('name', isEqualTo: tName)
//           .get();

//       for (var doc in querySnapshot.docs) {
//         // print('id:${doc.id}');
//         final docData = doc.data();

//         // print(docData);
//         await staffCollectionReference.doc(doc.id).update({'subjects': result});
//       }
//     }
//   } catch (e) {
//     rethrow;
//   }
// }