import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitcal/pages/giris3.dart';

class giris2 extends StatefulWidget {
  const giris2({Key? key}) : super(key: key);

  @override
  State<giris2> createState() => _Giris2State();
}

class _Giris2State extends State<giris2> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _besinCollection =
      FirebaseFirestore.instance.collection('besin');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  String _searchQuery = "";
  int _totalCalories = 0;
  int _targetCalories = 0;//h
  int _remainingCalories = 0;//k
  Map<String, int> foodCounts = {};

  @override
  void initState() {
    super.initState();
    _configureFirestoreCache();
    _user = _auth.currentUser;
    _loadUserData();
  }

  //firestore on bellek ayarı
  void _configureFirestoreCache() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  //veri cekmek
  Future<void> _loadUserData() async {
    if (_user == null) return;

    final userDoc = _usersCollection.doc(_user!.uid);

    try {
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>; // map yap
        setState(() {
          _totalCalories = data['toplamKalori'] ?? 0;
          _remainingCalories = data['kalanKalori'] ?? 0;
          _noteController.text = data['note'] ?? '';
        });
      }
    } catch (e) {
      print("Kullanıcı verisi yüklenirken hata oluştu: $e");
    }
  }

  Future<void> _updateCalories(int calorieChange) async {
    if (_user == null) return;

    final userDoc = _usersCollection.doc(_user!.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (snapshot.exists) {
          final totalCalories = snapshot['toplamKalori'] ?? 0;
          final targetCalories = snapshot['hedeflenenKalori'] ?? 0;
          final updatedTotal = totalCalories + calorieChange;
          final updatedRemaining = targetCalories - updatedTotal;

          transaction.update(userDoc, {
            'toplamKalori': updatedTotal,
            'kalanKalori': updatedRemaining,
          });

          // Günlük kalori değerlerini güncelle
          final today = DateTime.now().toIso8601String().split('T')[0];
          final userCaloriesDoc = userDoc.collection('gunlukKaloriler').doc(today);
          final todaySnapshot = await userCaloriesDoc.get();

          if (todaySnapshot.exists) {
            transaction.update(userCaloriesDoc, {
              'toplamKalori': updatedTotal,
              'kalanKalori': updatedRemaining,
            });
          } else {
            transaction.set(userCaloriesDoc, {
              'tarih': today,
              'hedeflenenKalori': targetCalories,
              'toplamKalori': updatedTotal,
              'kalanKalori': updatedRemaining,
            });
          }
        }
      });
    } catch (e) {
      print("Kalori güncellenirken hata oluştu: $e");
    }
  }

  Future<void> _addFoodToYenilenBesinler(String foodId, int calorie) async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen giriş yapın!")),
      );
      return;
    }

    final userDoc = _usersCollection.doc(_user!.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (!snapshot.exists) {
          transaction.set(userDoc, {
            'yenilenBesinler': [],
            'toplamKalori': 0,
            'kalanKalori': 0,
          });
        }

        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        List<dynamic> yenilenBesinler =
            List<dynamic>.from(data['yenilenBesinler'] ?? []);

        final existingFoodIndex = yenilenBesinler.indexWhere(
          (element) => element['id'] == foodId,
        );
        //besin varsa guncelle
        if (existingFoodIndex != -1) {
          final existingFood =
              Map<String, dynamic>.from(yenilenBesinler[existingFoodIndex]);
          existingFood['count'] = (existingFood['count'] ?? 0) + 1;
          existingFood['totalCalories'] =
              (existingFood['totalCalories'] ?? 0) + calorie;

          yenilenBesinler[existingFoodIndex] = existingFood;
          //yoksa ekle
        } else {
          yenilenBesinler.add({
            'id': foodId,
            'count': 1,
            'totalCalories': calorie,
          });
        }

        //firestorea kaydet
        transaction.update(userDoc, {
          'yenilenBesinler': yenilenBesinler,
        });

        // Toplam ve kalan kalorileri güncelle
        _updateCalories(calorie);
      });
    } catch (e) {
      print("Besin eklenirken hata oluştu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bir hata oluştu: $e")),
      );
    }
  }

  Future<void> _removeFoodFromYenilenBesinler(
      String foodId, int calorie) async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen giriş yapın!")),
      );
      return;
    }

    final userDoc = _usersCollection.doc(_user!.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (snapshot.exists) {
          List<dynamic> yenilenBesinler = snapshot['yenilenBesinler'] ?? [];

          var existingFood = yenilenBesinler.firstWhere(
            (element) => element['id'] == foodId,
            orElse: () => null,
          );

          if (existingFood != null) {
            existingFood['count'] -= 1;
            existingFood['totalCalories'] -= calorie;

            if (existingFood['count'] <= 0) {
              yenilenBesinler.remove(existingFood);
            }
          }

          transaction.update(userDoc, {
            'yenilenBesinler': yenilenBesinler,
          });

          // Toplam ve kalan kalorileri güncelle
          _updateCalories(-calorie);
        }
      });
    } catch (e) {
      print("Besin kaldırılırken hata oluştu: $e");
    }
  }

  Future<void> _saveNote() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen giriş yapın!")),
      );
      return;
    }

    try {
      await _usersCollection.doc(_user!.uid).update({
        'note': _noteController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not kaydedildi!")),
      );
    } catch (e) {
      print("Not kaydedilirken hata oluştu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bir hata oluştu: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(//geri tusu
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 255, 251, 240),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SizedBox(height: 50),
                            Text(
                              'Kendime',
                              style: TextStyle(
                                fontFamily: 'SpicyRice',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Not     :',
                              style: TextStyle(
                                fontFamily: 'SpicyRice',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 220,
                          height: 190,
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(190, 213, 244, 73),
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _noteController,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    hintText: 'Kendine not yaz',
                                    hintStyle: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'SpicyRice',
                                      color: Colors.grey,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontFamily: 'SpicyRice',
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _saveNote,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 210, 210, 210),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 40),
                                ),
                                child: const Text(
                                  "Kaydet",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color.fromARGB(255, 151, 150, 150),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          labelText: "Besin Adı Ara",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 480,
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
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _besinCollection.snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child:
                                    Text("Bir hata oluştu: ${snapshot.error}"));
                          }

                          final besinList = snapshot.data?.docs.where((doc) {
                            final isim = (doc['isim'] as String).toLowerCase();
                            return isim.contains(_searchQuery);
                          }).toList();

                          if (besinList == null || besinList.isEmpty) {
                            return const Center(
                                child: Text("Eşleşen besin bulunamadı."));
                          }

                          return SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    "Besin Adı",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    "Kalori",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(""),
                                ),
                              ],
                              rows: besinList.map((besin) {
                                final calorie =
                                    int.tryParse(besin['kalori'].toString()) ??
                                        0;
                                final foodId = besin.id;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(besin['isim'] ?? '')),
                                    DataCell(Text('$calorie kcal')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              _addFoodToYenilenBesinler(
                                                  foodId, calorie);
                                            },
                                            icon: const Icon(Icons.add),
                                            color: Colors.green,
                                          ),
                                         
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: OutlinedButton(//giris3 e yonelen
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => giris3()),
                            );
                          },
                          child: const Text(
                            'Listemi Gör',
                            style: TextStyle(
                              color: Color.fromRGBO(158, 184, 42, 0.639),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 35),
                            textStyle: const TextStyle(fontSize: 18),
                            side:
                                const BorderSide(color: Colors.black, width: 2),
                            backgroundColor:
                                const Color.fromARGB(255, 255, 251, 240),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Stack(
              children: [
                Positioned(
                  top: 20,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 232, 108, 25),
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
            )
          ],
        ),
      ),
    );
  }
}
