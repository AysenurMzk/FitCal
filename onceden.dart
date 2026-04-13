import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 

class onceden extends StatelessWidget {
  const onceden({Key? key}) : super(key: key);

Future<List<Map<String, dynamic>>> _fetchGunlukKaloriler() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception("Kullanıcı giriş yapmamış!");
  }

  // Kullanıcı belgesini al
  final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

  // Kullanıcı verilerini al
  final userSnapshot = await userDoc.get();
  if (!userSnapshot.exists) {
    throw Exception("Kullanıcı verisi bulunamadı!");
  }

  final userData = userSnapshot.data() as Map<String, dynamic>;
  final hedeflenenKalori = userData['hedeflenenKalori'] ?? 0;
  final toplamKalori = userData['toplamKalori'] ?? 0;
  final kalanKalori = userData['kalanKalori'] ?? 0;

  // Bugünün tarihini al
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd').format(now);

  // Bugünün belgesi kontrol edilir
  final todayDocRef = userDoc.collection('gunlukKaloriler').doc(formattedDate);
  final todayDocSnapshot = await todayDocRef.get();

  if (todayDocSnapshot.exists) {
    // Eğer bugünün belgesi varsa, verileri güncelle
    await todayDocRef.update({
      'toplamKalori': toplamKalori,
      'hedeflenenKalori': hedeflenenKalori,
      'kalanKalori': kalanKalori,
    });
  } else {
    // Eğer bugünün belgesi yoksa, yeni belge ekle
    await todayDocRef.set({
      'tarih': formattedDate,
      'toplamKalori': toplamKalori,
      'hedeflenenKalori': hedeflenenKalori,
      'kalanKalori': kalanKalori,
    });
  }

  // Tüm günlük kaloriler koleksiyonunu getir
  final gunlukKalorilerSnapshot = await userDoc.collection('gunlukKaloriler').get();

  return gunlukKalorilerSnapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'tarih': data['tarih'] ?? '',
      'toplamKalori': data['toplamKalori'] ?? 0,
      'hedeflenenKalori': data['hedeflenenKalori'] ?? 0,
      'kalanKalori': data['kalanKalori'] ?? 0,
    };
  }).toList();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Stack(
        children: [
          // AppBar İçeriği
          Column(
            children: [
              Container(
                color: const Color.fromARGB(190, 213, 244, 73),
                height: 100, // Başlık alanı yüksekliği
                child: Center(
                  child: Text(
                    'Yenilen Besinler',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontFamily: 'SpicyRice',
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              Expanded(//Firestoredan günlük kalori kayıtlarını alıp ekranda listelemek
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchGunlukKaloriler(),//listelemek için 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Hata oluştu: ${snapshot.error}'));
                    }

                    final gunlukKaloriler = snapshot.data ?? [];

                    if (gunlukKaloriler.isEmpty) {
                      return const Center(
                        child: Text(
                          'Hiçbir günlük kalori kaydı bulunamadı.',
                          style: TextStyle(fontSize: 18, fontFamily: 'SpicyRice'),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: gunlukKaloriler.length,
                      itemBuilder: (context, index) {
                        final kalori = gunlukKaloriler[index];

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                            title: Text(
                              'Tarih: ${kalori['tarih']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Toplam Kalori: ${kalori['toplamKalori']} kcal'),
                                Text('Hedeflenen Kalori: ${kalori['hedeflenenKalori']} kcal'),
                                Text('Kalan Kalori: ${kalori['kalanKalori']} kcal'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Geri Butonu
          Positioned(
            top: 30, // Başlık alanının içinde görünmesi için ayarlandı
            left: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 232, 108, 25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
