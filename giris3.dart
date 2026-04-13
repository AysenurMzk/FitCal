import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onceden.dart'; 

class giris3 extends StatefulWidget {
  const giris3({Key? key}) : super(key: key);

  @override
  State<giris3> createState() => _Giris3State();
}

class _Giris3State extends State<giris3> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _besinCollection =
      FirebaseFirestore.instance.collection('besin');
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  //silme azaltma ve anlık güncelleme
  Future<void> _decrementFoodItem(String foodId, int calorie) async {
    if (_user == null) return;

    final userDoc = _usersCollection.doc(_user!.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (snapshot.exists) {//var
          List<dynamic> yenilenBesinler = snapshot['yenilenBesinler'] ?? [];

          var existingFood = yenilenBesinler.firstWhere(
            (element) => element['id'] == foodId,
            orElse: () => null,
          );

          if (existingFood != null) {
            if (existingFood['count'] > 1) {
              existingFood['count'] -= 1;
              existingFood['totalCalories'] -= calorie;
            } else {
              yenilenBesinler.remove(existingFood);
            }

            transaction.update(userDoc, {
              'yenilenBesinler': yenilenBesinler,
              'toplamKalori': FieldValue.increment(-calorie),
              'kalanKalori': FieldValue.increment(calorie),
            });

            // Günlük kalori değerlerini güncelle
            final today = DateTime.now().toIso8601String().split('T')[0];//ISO nun kullandıgı ayrac T
            final userCaloriesDoc =
                userDoc.collection('gunlukKaloriler').doc(today);
            final todaySnapshot = await userCaloriesDoc.get();

            if (todaySnapshot.exists) {
              transaction.update(userCaloriesDoc, {
                'toplamKalori': FieldValue.increment(-calorie),
                'kalanKalori': FieldValue.increment(calorie),
              });
            } else {
              transaction.set(userCaloriesDoc, {
                'tarih': today,
                'toplamKalori': snapshot['toplamKalori'] - calorie,
                'kalanKalori': snapshot['kalanKalori'] + calorie,
                'hedeflenenKalori': snapshot['hedeflenenKalori'],
              });
            }
          }
        }
      });
    } catch (e) {
      print("Besin azaltılırken hata oluştu: $e");
    }
  }

  //besin adı cek
  Future<String> _getFoodName(String foodId) async {
    try {
      final foodDoc = await _besinCollection.doc(foodId).get();
      if (foodDoc.exists) {
        return foodDoc['isim'] ?? 'Bilinmiyor';
      } else {
        return 'Bilinmiyor';
      }
    } catch (e) {
      print("Besin adı alınırken hata oluştu: $e");
      return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 251, 240),
      appBar: AppBar(
        title: const Text(
          "Yenilen Besinler",
          style: TextStyle(fontFamily: 'SpicyRice', fontSize: 30),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(190, 213, 244, 73),
        leading: Padding(//geri
          padding: const EdgeInsets.all(10.0),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 108, 25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 60.0),
        child: Column(
          children: [
            Expanded(
              child: _user == null
                  ? const Center(
                      child: Text(
                        "Lütfen giriş yapın!",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _usersCollection.doc(_user!.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                              child: Text(
                                  "Veri yüklenirken bir hata oluştu: ${snapshot.error}"));
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(
                              child: Text("Herhangi bir veri bulunamadı."));
                        }

                        var userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        List<dynamic> yenilenBesinler =
                            userData['yenilenBesinler'] ?? [];

                        if (yenilenBesinler.isEmpty) {
                          return const Center(
                              child: Text(
                                  "Hiç besin eklenmemiş. Liste şu anda boş."));
                        }
                        //listeye ekleme
                        return FutureBuilder<List<DataRow>>(
                          future: Future.wait(
                            yenilenBesinler.map((besin) async {
                              String foodName = await _getFoodName(besin['id']);
                              return DataRow(
                                cells: [
                                  DataCell(Text(foodName)),
                                  DataCell(Text("${besin['count']} adet")),
                                  DataCell(Text("${besin['totalCalories']} kcal")),
                                  DataCell(
                                    IconButton(
                                      onPressed: () {
                                        _decrementFoodItem(besin['id'],
                                            besin['totalCalories'] ~/
                                                besin['count']);
                                      },
                                      icon: const Icon(Icons.remove,
                                          color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          builder: (context, asyncSnapshot) {
                            if (asyncSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (asyncSnapshot.hasError) {
                              return Center(
                                  child: Text(
                                      "Veri yüklenirken bir hata oluştu: ${asyncSnapshot.error}"));
                            }

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        "Besin Adı",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Miktar",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        "Toplam Kalori",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(""),
                                    ),
                                  ],
                                  rows: asyncSnapshot.data ?? [],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const onceden()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 33, vertical: 13),
                backgroundColor: const Color.fromARGB(255, 232, 108, 25),
              ),
              child: const Text(
                "Önceden Yediklerim",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
