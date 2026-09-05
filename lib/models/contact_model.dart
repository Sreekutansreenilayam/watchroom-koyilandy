import 'dart:convert';

class ContactModel {
  final String id;
  final String name;
  final String category;
  final String phoneNumber;
  final String? alternativeNumber;
  final String? designation;
  final int orderIndex;

  ContactModel({
    required this.id,
    required this.name,
    required this.category,
    required this.phoneNumber,
    this.alternativeNumber,
    this.designation,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'phoneNumber': phoneNumber,
      'alternativeNumber': alternativeNumber,
      'designation': designation,
      'orderIndex': orderIndex,
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      alternativeNumber: map['alternativeNumber'],
      designation: map['designation'],
      orderIndex: map['orderIndex'] ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory ContactModel.fromJson(String source) => ContactModel.fromMap(json.decode(source));
}
