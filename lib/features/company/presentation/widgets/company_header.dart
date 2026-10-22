import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/company_repository.dart';
import 'company_badge.dart';

/// The signed-in recruiter's company with its verified badge
/// (`companies.verified`, RC-22). [compact] shows just the logo with the
/// status in a tooltip, for the collapsed rail.
class CompanyHeader extends ConsumerWidget {
  const CompanyHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myCompanyProvider).value;
    if (membership == null) return const SizedBox.shrink();
    final company = membership.company;
    final logoUrl = ref
        .watch(companyRepositoryProvider)
        .logoUrl(company.logoPath);
    final logo = CompanyLogo(name: company.name, url: logoUrl, size: 36);
    if (compact) {
      return Tooltip(
        message:
            '${company.name} · ${company.verified ? 'Verified' : 'Unverified'}',
        child: Semantics(
          label:
              '${company.name}, ${company.verified ? 'verified' : 'unverified'} company',
          excludeSemantics: true,
          child: logo,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                company.name,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              CompanyBadge(verified: company.verified),
            ],
          ),
        ),
      ],
    );
  }
}

/// Company name + badge on one line, for app bar subtitles on phones.
class CompanySubtitle extends ConsumerWidget {
  const CompanySubtitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myCompanyProvider).value;
    if (membership == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            membership.company.name,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: CompanyBadge(verified: membership.company.verified)),
      ],
    );
  }
}
