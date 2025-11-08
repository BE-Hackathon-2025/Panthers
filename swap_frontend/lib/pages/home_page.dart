import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('You are signed in.', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
