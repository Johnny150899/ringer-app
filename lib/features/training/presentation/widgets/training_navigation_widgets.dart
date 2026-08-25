part of '../screens/training_screen.dart';

class _DatedTrainingSession {
  const _DatedTrainingSession(this.session, this.date);

  final TrainingSession session;
  final DateTime date;
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _MonthButton(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppGlassIconButton(icon: icon, onPressed: onTap, size: 40);
  }
}

class _MemberGroupFilter extends StatelessWidget {
  const _MemberGroupFilter({required this.selected, required this.onSelected});

  static const _groups = ['Männer', 'Jugend', 'Bambinis'];
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      borderRadius: 14,
      padding: const EdgeInsets.all(3),
      child: Row(
        children: _groups.indexed
            .map((entry) {
              final index = entry.$1;
              final group = entry.$2;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _groups.length - 1 ? 3 : 0,
                  ),
                  child: Semantics(
                    selected: selected == group,
                    button: true,
                    child: InkWell(
                      key: ValueKey('member-group-$group'),
                      onTap: () => onSelected(group),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected == group
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected == group
                                ? Colors.white
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              group,
                              style: TextStyle(
                                color: selected == group
                                    ? AppColors.navy
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
