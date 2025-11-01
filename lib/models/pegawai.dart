class Pegawai {
  final String id;
  final String name;
  final String nik;
  final String position;
  final String code;
  Pegawai({required this.id, required this.name, required this.nik, required this.position, required this.code});

  factory Pegawai.fromJson(Map<String, dynamic> json) => Pegawai(
        id: json['id'],
        name: json['name'],
        nik: json['nik'],
        position: json['position'],
        code: json['code'],
      );
}
