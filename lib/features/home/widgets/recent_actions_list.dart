import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/action_card.dart';
import '../home_provider.dart';

class RecentActionsList extends StatelessWidget {
  const RecentActionsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recentActions = context.select<HomeProvider, List>((p) => p.recentActions);

    if (recentActions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Text(
          "No recent actions. Try asking Saarthi to do something!",
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: recentActions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return ActionCard(action: recentActions[index]);
      },
    );
  }
}
