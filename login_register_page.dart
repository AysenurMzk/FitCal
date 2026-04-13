import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitcal/service/auth.dart';
import 'package:flutter/material.dart';
import 'package:fitcal/pages/giris1.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginRegisterPage extends StatefulWidget {
  const LoginRegisterPage({super.key});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final TextEditingController usernamecontroller = TextEditingController();

  bool isLogin = true;
  String? errorMessage;
  String? successMessage;

  Future<void> addUsernameToFirestore(
      String uid, String username, String password) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        // kayıt saglar
        'username': username,
        'email': emailcontroller.text,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Veritabanı hatası: ${e.toString()}';
      });
    }
  }

  // Üye oluşturma işlemi
  Future<void> createUser() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailcontroller.text,
        password: passwordcontroller.text,
      );

      //  ad ekle
      await addUsernameToFirestore(userCredential.user!.uid,
          usernamecontroller.text, passwordcontroller.text);

      setState(() {
        successMessage = 'Üye olundu!';
      });

      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          successMessage = null; // mesajını gizle
        });

        //giriş ekranına yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginRegisterPage()),
        );
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Bu e-posta zaten kullanılıyor.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Şifre çok zayıf, daha güçlü bir şifre belirleyin.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Geçersiz e-posta adresi formatı.';
        } else {
          errorMessage = 'Bir hata oluştu: ${e.message}';
        }
      });
    }
  }

  // giris yapma islemi
  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailcontroller.text,
        password: passwordcontroller.text,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const giris1()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = 'Böyle bir kullanıcı bulunamadı.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Yanlış şifre, lütfen tekrar deneyin.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Geçersiz e-posta adresi formatı.';
        } else {
          errorMessage = 'Bir hata oluştu: ${e.message}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 255, 251, 240), // Açık krem rengi
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/avokado.png',
                    width: 70,
                    height: 70,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "FitCal",
                    style: TextStyle(
                      fontFamily: 'SpicyRice',
                      fontSize: 55,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            Colors.green.shade800,
                            const Color.fromARGB(255, 21, 59, 23)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                      shadows: [
                        Shadow(
                          blurRadius: 15.0,
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(5.0, 5.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              if (!isLogin) ...[
                TextField(
                  controller: usernamecontroller,
                  decoration: InputDecoration(
                    hintText: "Kullanıcı Adı",
                    hintStyle: TextStyle(color: Colors.black),
                    filled: true,
                    fillColor: Colors.green[400],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.deepOrange),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              TextField(
                controller: emailcontroller,
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.green[400],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[800]!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: passwordcontroller,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Şifre Giriniz",
                  hintStyle: TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.green[400],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[800]!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),

              successMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        successMessage!,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5, //golge
                ),
                onPressed: () {
                  if (isLogin) {
                    signIn();
                  } else {
                    createUser();
                  }
                },
                child: isLogin ? const Text("Giriş Yap") : const Text("Üye Ol"),
              ),
              const SizedBox(height: 20),

              // switch  login ve kayıt
              GestureDetector(
                onTap: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin
                      ? "Üye değil misin? Üye ol"
                      : "Zaten üye misiniz? Giriş yap",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
