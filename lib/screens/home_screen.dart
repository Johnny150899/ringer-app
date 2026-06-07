import 'package:flutter/material.dart';
import '../services/ligadb_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: LigaDbService().getAllKscMatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Fehler: ${snapshot.error}'),
          );
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return const Center(
            child: Text('Keine Kämpfe gefunden'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];

            return Card(
              child: ListTile(
                title: Text(
                  '${match['HeimMannschaft']} vs ${match['GastMannschaft']}',
                ),
                subtitle: Text(
                  'Beginn: ${match['Beginn']}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}