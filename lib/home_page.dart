import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        child: ElevatedButton(
          onPressed: () {
            selectOnboardingExcelFile();
          },
          child: const Text('Excel update'),
        ),
      ),
    );
  }
}

FirebaseFirestore firestore = FirebaseFirestore.instance;
CollectionReference collectionReference = firestore.collection('Schools');
WriteBatch schoolBasicInfoBatch = firestore.batch();
WriteBatch clssesInfoBatch = firestore.batch();
WriteBatch staffInfoBatch = firestore.batch();
WriteBatch studentInfoBatch = firestore.batch();
WriteBatch subAlloBatch = firestore.batch();

Future<bool> selectOnboardingExcelFile() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) {
      return false;
    }

    var bytes = result.files.first.bytes!;

    var excel = Excel.decodeBytes(bytes);

    var listOfSheets = excel.tables.keys.toList();

    String schoolBasicInfoDocId = '';
    for (var sheet in listOfSheets) {
      List<Map<String, dynamic>> jsonData =
          traverseExcelData(excel.tables[sheet]!);

      if (jsonData.isNotEmpty) {
        if (sheet == 'School Basic Information') {
          schoolBasicInfoDocId = await uploadToSchoolBasicInformation(
            batch: schoolBasicInfoBatch,
            collectionName: 'Schools',
            dataList: jsonData,
          );
          // print('School Basic Information$jsonData');
          await schoolBasicInfoBatch.commit();
        }
        if (sheet == 'Classes Information') {
          await uploadToClassInformation(
            batch: clssesInfoBatch,
            dataList: jsonData,
            schoolId: schoolBasicInfoDocId,
            collectionName: 'Schools',
          );
          // print('Classes Information$jsonData');
          await clssesInfoBatch.commit();
        }
        if (sheet == 'Staff Information') {
          await uploadToStaffInformation(
            batch: staffInfoBatch,
            collection: 'Staff',
            dataList: jsonData,
            schoolId: schoolBasicInfoDocId,
          );
          // print('Staff Information$jsonData');
          await staffInfoBatch.commit();
        }
        if (sheet == 'Student Information') {
          await uploadToStudentInformation(
            batch: studentInfoBatch,
            collectionName: 'Students',
            dataList: jsonData,
            schoolId: schoolBasicInfoDocId,
          );
          // print('Student Information$jsonData');
          await studentInfoBatch.commit();
        }
        if (sheet == 'Subject Allocation') {
          await uploadToStaffSubjectAllocation(
            collectionRef: collectionReference,
            dataList: jsonData,
            schoolId: schoolBasicInfoDocId,
          );
          // print('Subject Allocation$jsonData');
        }
      } else {
        return false;
      }
    }

    return true;
  } catch (e) {
    debugPrint('Error processing Excel file: $e');
    return false;
  }
}

//Subject Allocation
Future<void> uploadToStaffSubjectAllocation({
  required CollectionReference collectionRef,
  required String schoolId,
  required List<Map<String, dynamic>> dataList,
}) async {
  CollectionReference staffCollectionReference =
      FirebaseFirestore.instance.collection('Staff');
  try {
    for (var staff in dataList) {
      String tName = staff['staff_name'];
      String grade = staff['grade'];
      String sections = staff['sections'];
      String subjects = staff['subject_name'];

      List<String> sectionList = sections.split(',');
      List<String> subjectList = subjects.split(',');
      List<Map<String, String>> staffSubjects = [];

      Map<String, dynamic> subjectAllocation = {};

      QuerySnapshot querySnapshot = await staffCollectionReference
          .where('schoolID', isEqualTo: collectionRef.doc(schoolId))
          .where('name', isEqualTo: tName)
          .get();

      var doc = querySnapshot.docs[0];

      //Put this inside batch --------------------
      for (String section in sectionList) {
        for (String subject in subjectList) {
          staffSubjects.add({
            'grade': grade,
            'section': section.trim(),
            'subjectname': subject.trim()
          });

          subjectAllocation['grade'] = grade;
          subjectAllocation['section'] = section.trim();
          subjectAllocation['subjectname'] = subject.trim();
          subjectAllocation['tName'] = tName;
          subjectAllocation['tid'] = staffCollectionReference.doc(doc.id);

          collectionRef
              .doc(schoolId)
              .collection('SubjectAllocation')
              .doc()
              .set(subjectAllocation);
        }
      }
      await staffCollectionReference
          .doc(doc.id)
          .update({'subjects': staffSubjects});
    }

    //----------------------------------------------
  } catch (e) {
    rethrow;
  }
}

// Student Information
Future<void> uploadToStudentInformation({
  required WriteBatch batch,
  required String collectionName,
  required List<Map<String, dynamic>> dataList,
  required String schoolId,
}) async {
  try {
    for (var data in dataList) {
      String birthDateString = data['Birth_Date'];
      // debugPrint('birthDateString: $birthDateString');

      Timestamp timestamp = timeStampComverter(birthDateString);
      DocumentReference<Map<String, dynamic>> docRef =
          firestore.collection(collectionName).doc();

      batch.set(docRef, {
        'fatherName': data['Father_Name'],
        'fatherNum': data['Contact_Number'],
        'grade': data['Grade'],
        'motherName': data['Mother_Name'],
        'motherNum': data['Mother_Contact'],
        'name': data['Full_Name'],
        'sID': docRef.id,
        'schoolID': collectionReference.doc(schoolId),
        'section': data['Section'],
        'DOB': timestamp, //
        'aadharNum': data['Aadhar_Card'],
        'grNum': data['GR_Num'],
        'stdID': data['Student_ID'],
        'caste': data['Caste'],
        'category': data['Category'],
        'religion': data['Religion'],
        'isDisable': data['Any_Disability'] == 'No' ? false : true,
        'gender': data['Gender'],
        'houseColor': data['House_Colour'],
        'bloodGrp': data['BG'],
        'address': data['Student_Address'],
      });
    }
  } catch (e) {
    debugPrint('Error adding to batch: $e');
    rethrow;
  }
}

Timestamp timeStampComverter(String birthDateString) {
  if (birthDateString == '' || birthDateString == '-') {
    return Timestamp(0, 0);
  } else {
    DateTime birthDate =
        DateFormat('yyyy-MM-ddTHH:mm:ss.SSSZ').parse(birthDateString);
    // debugPrint('birthDate: $birthDate');

    return Timestamp.fromDate(birthDate);
  }
}

// Staff Information sheet
Future<void> uploadToStaffInformation({
  required WriteBatch batch,
  required String collection,
  required List<Map<String, dynamic>> dataList,
  required String schoolId,
}) async {
  try {
    for (var data in dataList) {
      Timestamp timestamp = timeStampComverter(data['dob']);
      List<String> roles = [];
      roles.add(data['staff_job_title']);
      DocumentReference<Map<String, dynamic>> docRef =
          firestore.collection(collection).doc();

      batch.set(docRef, {
        'name': data['staff_name'],
        'role': roles,
        'title': data['staff_job_title'],
        'DOB': timestamp,
        'phoneNum': data['phone_number'],
        'staffID': '',
        'schoolID': collectionReference.doc(schoolId),
      });

      batch.update(docRef, {'staffID': docRef.id});
    }
  } catch (e) {
    debugPrint('Error adding to batch: $e');
    rethrow;
  }
}

// Classes Information sheet
Future<void> uploadToClassInformation({
  required WriteBatch batch,
  required String collectionName,
  required List<Map<String, dynamic>> dataList,
  required String schoolId,
}) async {
  try {
    List<Map<String, dynamic>> sectionsList = [];
    List<String> classesList = [];

    for (var data in dataList) {
      List<String> sections = [];
      for (int i = 1; i <= 2; i++) {
        String sectionName = data['section_name$i'];
        if (sectionName.isNotEmpty) {
          sections.add(sectionName);
        }
      }
      sectionsList.add({
        'grade': data['grade'],
        'sections': sections,
      });

      String grade = data['grade'];
      if (!classesList.contains(grade)) {
        classesList.add(grade);
      }
      // print('sections $sections');
    }

    DocumentReference<Map<String, dynamic>> docRef =
        firestore.collection(collectionName).doc(schoolId);

    // print('classesList $classesList');
    // print('sectionsList $sectionsList');

    batch.update(docRef, {
      'sections': sectionsList,
      'classes': classesList,
    });
  } catch (e) {
    debugPrint('Error adding to batch: $e');
    rethrow;
  }
}

// SchoolBasicInformation sheet
Future<String> uploadToSchoolBasicInformation({
  required WriteBatch batch,
  required String collectionName,
  required List<Map<String, dynamic>> dataList,
}) async {
  try {
    for (var data in dataList) {
      DocumentReference<Map<String, dynamic>> docRef =
          FirebaseFirestore.instance.collection(collectionName).doc();

      batch.set(docRef, {
        'name': data['school_name'],
        'Address': {
          'streetName': data['streetName'],
          'city': data['city'],
          'district': data['district'],
          'pincode': data['pincode'],
          'state': data['state'],
          'country': data['country'],
        },
        'contactPerson': data['your_name'],
        'contactNum': data['your_phone_number'],
        'parentOrgName': data['parent_Org_Name'],
        'contactPersonRole': data['your_job_role'],
        'schoolID': '',
        'status': 'onboarded',
        'joinDate': Timestamp.now()
      });

      // Add the update operation to the batch
      batch.update(docRef, {'schoolID': docRef.id});

      return docRef.id;
    }
  } catch (e) {
    debugPrint('Error uploading to Firestore: $e');
    rethrow;
  }
  return '';
}

List<Map<String, dynamic>> traverseExcelData(Sheet sheet) {
  List<Map<String, dynamic>> jsonData = [];

  if (sheet.maxRows == 0) {
    return jsonData;
  }

  var headers =
      sheet.row(0).map((cell) => cell?.value?.toString().trim() ?? '').toList();

  for (var i = 1; i < sheet.maxRows; i++) {
    Map<String, dynamic> rowMap = {};
    if (sheet.rows[i]
        .every((cell) => cell?.value?.toString().trim().isEmpty ?? true)) {
      break;
    }

    for (var j = 0; j < sheet.maxColumns; j++) {
      var header = headers[j];
      var cellValue = sheet.row(i)[j]?.value?.toString().trim() ?? '';
      rowMap[header] = cellValue;
    }

    jsonData.add(rowMap);
  }

  return jsonData;
}
