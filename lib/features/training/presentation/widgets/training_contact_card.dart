part of '../screens/training_screen.dart';

class _TrainingContactCard extends StatelessWidget {
  const _TrainingContactCard({
    required this.info,
    required this.canEdit,
    required this.onEdit,
  });

  final TrainingContactInfo info;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trainingshalle & Kontakt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Kontaktdaten bearbeiten',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          _TrainingInfoRow(
            icon: Icons.sports_mma_rounded,
            title: info.clubName,
            detail: info.address,
          ),
          Divider(height: 22, color: Colors.white.withValues(alpha: .14)),
          _TrainingInfoRow(
            icon: Icons.person_outline_rounded,
            title: 'Ansprechpartner',
            detail: info.contactName,
          ),
          const SizedBox(height: 11),
          _TrainingInfoRow(
            icon: Icons.phone_outlined,
            title: 'Telefon',
            detail: info.phone,
          ),
          const SizedBox(height: 11),
          _TrainingInfoRow(
            icon: Icons.mail_outline_rounded,
            title: 'E-Mail',
            detail: info.email,
          ),
        ],
      ),
    );
  }
}

class _ContactTextField extends StatelessWidget {
  const _ContactTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Bitte ausfüllen' : null,
      ),
    );
  }
}

class _TrainingInfoRow extends StatelessWidget {
  const _TrainingInfoRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
