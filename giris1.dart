import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fitcal/pages/giris2.dart';

class giris1 extends StatefulWidget {
  const giris1({Key? key}) : super(key: key);

  @override
  State<giris1> createState() => _Giris1State();
}

class _Giris1State extends State<giris1> {
  final TextEditingController calorieController = TextEditingController();
  final TextEditingController boyController = TextEditingController();
  final TextEditingController kiloController = TextEditingController();
  double? vki;
  int kalanKalori=0;

  Future<void> updateKalanKalori(String kullaniciId) async {
    try {
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(kullaniciId);

      DocumentSnapshot userDoc = await userDocRef.get();

      if (userDoc.exists) {
        int hedeflenenKalori = (userDoc.data() as Map<String, dynamic>)['hedeflenenKalori'] ?? 0;
        int toplamKalori = userDoc['toplamKalori'] ?? 0;
        int yeniKalanKalori = hedeflenenKalori - toplamKalori;

        // `users` koleksiyonundaki kalan kalori güncellenir
        await userDocRef.update({'kalanKalori': yeniKalanKalori});

        // Alt koleksiyondaki bugünkü veri güncellenir
        await updateGunlukKalorilerCollection(kullaniciId, hedeflenenKalori, toplamKalori, yeniKalanKalori);
      }
    } catch (e) {
      print('Kalan kalori güncellenirken hata oluştu: $e');
    }
  }

  Future<void> updateGunlukKalorilerCollection(
      String kullaniciId, int hedeflenenKalori, int toplamKalori, int kalanKalori) async {
    try {
      String bugun = DateTime.now().toIso8601String().split('T')[0];
      DocumentReference gunlukKaloriDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(kullaniciId)
          .collection('gunlukKaloriler')
          .doc(bugun);

      // Firestore'daki bugünkü belgeyi oku
      DocumentSnapshot gunlukKaloriDoc = await gunlukKaloriDocRef.get();

      if (gunlukKaloriDoc.exists) {
        // Var olan bugünkü belgeyi güncelle
        await gunlukKaloriDocRef.update({
          'hedeflenenKalori': hedeflenenKalori,
          'toplamKalori': toplamKalori,
          'kalanKalori': kalanKalori,
        });
      } else {
        // Yeni belge oluştur
        await gunlukKaloriDocRef.set({
          'tarih': bugun,
          'hedeflenenKalori': hedeflenenKalori,
          'toplamKalori': toplamKalori,
          'kalanKalori': kalanKalori,
        });
      }
    } catch (e) {
      print('GunlukKaloriler güncellenirken hata oluştu: $e');
    }
  }

  void saveCalorieToFirestore(String kullaniciId) async {
    String hedeflenenKaloriStr = calorieController.text.trim();

    if (hedeflenenKaloriStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen bir hedef kalori giriniz.')),
      );
      return;
    }

    try {
      int hedeflenenKalori = int.tryParse(hedeflenenKaloriStr) ?? 0;

      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(kullaniciId);
      DocumentSnapshot userDoc = await userDocRef.get();

      if (!userDoc.exists) {
       await userDocRef.set({
  'email': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
  'username': FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown',
  'createdAt': FieldValue.serverTimestamp(),
  'hedeflenenKalori': hedeflenenKalori,
  'toplamKalori': 0, // Mutlaka eklenmeli
  'kalanKalori': hedeflenenKalori,
});

        // Yeni kullanıcı için alt koleksiyon oluşturma
        await updateGunlukKalorilerCollection(kullaniciId, hedeflenenKalori, 0, hedeflenenKalori);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yeni kullanıcı oluşturuldu ve hedef kalori kaydedildi.')),
        );
      } else {
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        int toplamKalori = userData != null && userData.containsKey('toplamKalori')
            ? userData['toplamKalori'] ?? 0
            : 0;

        int kalanKalori = hedeflenenKalori - toplamKalori;

        await userDocRef.update({
          'hedeflenenKalori': hedeflenenKalori,
          'kalanKalori': kalanKalori,
          'toplamKalori': toplamKalori,

        });

        updateKalanKalori(kullaniciId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hedef kalori ve kalan kalori güncellendi.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e')),
      );
    }
  }
//dinamik olarak kullanıcıya kalori yuklemeyi sağlar
  void _loadUserCalorie() async {
    try {
      String kullaniciId = await _getUserId();
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(kullaniciId).get();

      if (userDoc.exists) {
        int hedeflenenKalori = userDoc['hedeflenenKalori'] ?? 0;
        int toplamKalori = userDoc['toplamKalori'] ?? 0;
        int kalanKalori = hedeflenenKalori - toplamKalori;

        setState(() {
          this.kalanKalori = kalanKalori;
        });

        if (userDoc['kalanKalori'] == null || userDoc['kalanKalori'] != kalanKalori) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(kullaniciId)
              .update({'kalanKalori': kalanKalori});
        }

        // Alt koleksiyon güncellemesi
        await updateGunlukKalorilerCollection(kullaniciId, hedeflenenKalori, toplamKalori, kalanKalori);
      }
    } catch (e) {
      print('Kalori verisi yüklenirken bir hata oluştu: $e');
    }
  }

  Future<String> _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    } else {
      throw Exception("Kullanıcı giriş yapmamış!");
    }
  }
  //miras alma
  @override
  void initState() {
    super.initState();
    _loadUserCalorie();
  }
  
  // Boy, kilo ve VKI bilgisini Firestore'a kaydetmek için işlev
void saveBoyKiloVKIToFirestore(String kullaniciId) async {
  String boy = boyController.text.trim();
  String kilo = kiloController.text.trim();

  if (boy.isEmpty || kilo.isEmpty || vki == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lütfen geçerli bir boy, kilo ve VKI hesaplayınız.')),
    );
    return;
  }

  try {
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(kullaniciId);

    // Kullanıcı dokümanını al
    DocumentSnapshot userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      // Eğer kullanıcı dokümanı yoksa, yeni kullanıcı oluştur
      await userDocRef.set({
        'email': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'username': FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'boy': double.parse(boy),
        'kilo': double.parse(kilo),
        'vki': vki,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeni kullanıcı oluşturuldu ve boy, kilo, VKI kaydedildi.')),
      );
    } else {
      // Kullanıcı dokümanı varsa güncelle
      await userDocRef.update({
        'boy': double.parse(boy),
        'kilo': double.parse(kilo),
        'vki': vki,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Boy, kilo ve VKI güncellendi.')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bir hata oluştu: $e')),
    );
  }
}




  void hesaplaVKI() {
    double boy = double.tryParse(boyController.text) ?? 0;
    double kilo = double.tryParse(kiloController.text) ?? 0;

    if (boy > 0 && kilo > 0) {
      setState(() {
        vki = kilo / ((boy / 100) * (boy / 100));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen geçerli bir boy ve kilo giriniz.')),
      );
    }
  }
 String _vkiKategorisi(double vki) {
    if (vki < 18.5) {
      return "Zayıfsınız";
    } else if (vki >= 18.5 && vki < 24.9) {
      return "Normalsiniz";
    } else if (vki >= 25 && vki < 29.9) {
      return "Şişmansınız";
    } else {
      return "Obezsiniz";
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 251, 240),
      body: Padding(
        padding: const EdgeInsets.only(left: 10.0, top: 39.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                "Hoşgeldiniz!",
                style: TextStyle(
                  fontFamily: 'SpicyRice',
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      blurRadius: 5.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            // Diğer Alanlar
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text("Hata: ${snapshot.error}");
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Text("Veri bulunamadı");
                    }

                    var userData = snapshot.data!.data() as Map<String, dynamic>;
                    int toplamKalori = userData.containsKey('toplamKalori') ? userData['toplamKalori'] ?? 0 : 0;

                    int hedeflenenKalori = userData.containsKey('hedeflenenKalori') ? userData['hedeflenenKalori'] ?? 0 : 0;
                    int kalanKalori = userData.containsKey('kalanKalori') ? userData['kalanKalori'] ?? 0 : 0;
                    double boy = userData.containsKey('boy') ? userData['boy'] ?? 0.0 : 0.0;
                   double kilo = userData.containsKey('kilo') ? userData['kilo'] ?? 0.0 : 0.0;

                    return Container(
                      width: 170,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(190, 213, 244, 73),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              "Alınan kalori:",
                              style: TextStyle(
                                fontFamily: 'SpicyRice',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 0),
                            Divider(
                              thickness: 2,
                              color: Colors.black,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "$toplamKalori",
                                style: TextStyle(
                                  fontFamily: 'SpicyRice',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 25),
                Container(
                  width: 180,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(190, 213, 244, 73),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                          "Hedeflenen kalori:",
                          style: TextStyle(
                            fontFamily: 'SpicyRice',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Divider(
                          thickness: 2,
                          color: Colors.black,
                        ),
                        TextField(
                          controller: calorieController,
                          decoration: InputDecoration(
                            hintText: "Örn;1349",
                            hintStyle: TextStyle(
                              color: const Color.fromARGB(141, 189, 189, 189),
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            fontFamily: 'SpicyRice',
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          width: 95,
                          height: 25,
                          margin: const EdgeInsets.only(top: 13),
                          child: ElevatedButton(
                            onPressed: () async {
                              String kullaniciId = await _getUserId();
                              saveCalorieToFirestore(kullaniciId);
                            },
                            child: Text(
                              "Kaydet",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 30),
// Bilgilendirme Metni
Text(
  "Lütfen boy ve kilonuzu giriniz",
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: Colors.black,
  ),
  textAlign: TextAlign.center,
),
const SizedBox(height: 20),
// Boy ve Kilo Bilgisi Alanı
TextField(
  controller: boyController,
  decoration: InputDecoration(
    labelText: "Boy (cm)",
    border: OutlineInputBorder(),
    filled: true,
                fillColor: Colors.white,
  ),
  keyboardType: TextInputType.number,
),
const SizedBox(height: 10),
TextField(
  controller: kiloController,
  decoration: InputDecoration(
    labelText: "Kilo (kg)",
    border: OutlineInputBorder(),
    filled: true,
                fillColor: Colors.white,
  ),
  keyboardType: TextInputType.number,
  
),
const SizedBox(height: 20),
OutlinedButton(
  onPressed: () async {
    // İlk önce VKI hesapla
    hesaplaVKI();
    
    // Sonrasında verileri Firestore'a kaydet
    String kullaniciId = await _getUserId();
    saveBoyKiloVKIToFirestore(kullaniciId); // Bu fonksiyon Firestore'a kaydediyor
  },
  child: const Text("Vücut Kitle İndeksi Hesapla", style: TextStyle(
                      color: Color.fromRGBO(158, 184, 42, 0.639),
                    ),),
  style: OutlinedButton.styleFrom(
    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
    textStyle: TextStyle(fontSize: 14),
    side: BorderSide(color: Colors.black, width: 2),
    backgroundColor: Color.fromARGB(255, 255, 251, 240),
  ),
),


const SizedBox(height: 8),

// VKI Sonucu
if (vki != null)

    Row(
  mainAxisAlignment: MainAxisAlignment.start, // Sol tarafa hizalama
  children: [
    Text(
      "Vücut Kitle İndeksi: ${vki!.toStringAsFixed(2)}",
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    ),
    SizedBox(width: 10), // Yazılar arasında boşluk bırakmak için
    Text(
      _vkiKategorisi(vki!),
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    ),
  ],
),   

 
   const SizedBox(height: 20),

  
            StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }

    if (snapshot.hasError) {
      return Text("Hata: ${snapshot.error}");
    }

    if (!snapshot.hasData || !snapshot.data!.exists) {
      return Text("Veri bulunamadı");
    }

    var userData = snapshot.data!.data() as Map<String, dynamic>;
    int kalanKalori = userData['kalanKalori'] ?? 0;

    return Container(
      width: 180,
      height: 150,
      decoration: BoxDecoration(
        color: Color.fromARGB(190, 213, 244, 73),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              "Kalan kalori:",
              style: TextStyle(
                fontFamily: 'SpicyRice',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 0),
            Divider(
              thickness: 2,
              color: Colors.black,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "$kalanKalori",
                style: TextStyle(
                  fontFamily: 'SpicyRice',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
),


             Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => giris2()),
                    );
                  },
                  child: Text(
                    'Yiyecek Kalorisi Ekle',
                    style: TextStyle(
                      color: Color.fromRGBO(158, 184, 42, 0.639),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                    textStyle: TextStyle(fontSize: 18),
                    side: BorderSide(color: Colors.black, width: 2),
                    backgroundColor: Color.fromARGB(255, 255, 251, 240),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    
  }
}

