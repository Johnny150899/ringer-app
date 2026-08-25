import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/training_contact_info.dart';

class TrainingContactService {
  const TrainingContactService(this._client);

  final SupabaseClient _client;

  Future<TrainingContactInfo> load() async {
    final row = await _client
        .from('club_contact_info')
        .select('club_name, training_address, contact_name, phone, email')
        .eq('id', true)
        .maybeSingle();
    return row == null
        ? TrainingContactInfo.defaults
        : TrainingContactInfo.fromJson(row);
  }

  Future<void> update(TrainingContactInfo info) async {
    await _client
        .from('club_contact_info')
        .update(info.toJson())
        .eq('id', true);
  }
}
