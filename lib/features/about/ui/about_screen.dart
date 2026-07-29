import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/functions/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../data/about_constants.dart';
import 'widgets/about_app_header.dart';
import 'widgets/about_flat_row.dart';
import 'widgets/about_section_label.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: rw(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              verticalSpacing(16),

              // ── Back ──────────────────────────────────────────────
              GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: rr(20),
                    color: colors.textPrimary,
                  ),
                ),
              ),
              verticalSpacing(24),

              // ── App Header ────────────────────────────────────────
              const AboutAppHeader(),
              verticalSpacing(20),

              // ── App Info ──────────────────────────────────────────
              AboutSectionLabel('about.sections.app_info'.tr()),
              verticalSpacing(12),
              AboutFlatRow(
                icon: Icons.smartphone_rounded,
                label: 'about.app_info.platform'.tr(),
                trailing: isIos
                    ? 'about.app_info.platform_ios'.tr()
                    : 'about.app_info.platform_android'.tr(),
              ),
              AboutFlatRow(
                icon: Icons.grid_view_rounded,
                label: 'about.app_info.package'.tr(),
                trailing: isIos
                    ? AboutConstants.iosStoreUrl.split('/').last
                    : AboutConstants.androidStoreUrl.split('=').last,
              ),
              AboutFlatRow(
                icon: Icons.update_rounded,
                label: 'about.app_info.last_updated'.tr(),
                trailing: _currentYear,
                showDivider: false,
              ),
              verticalSpacing(20),

              // ── Developer ─────────────────────────────────────────
              AboutSectionLabel('about.sections.developer'.tr()),
              verticalSpacing(12),
              const AboutFlatRow(
                icon: Icons.person_outline_rounded,
                label: AppConfig.developerName,
              ),
              AboutFlatRow(
                icon: Icons.email_outlined,
                label: AppConfig.developerEmail,
                // onTap: () => switchTheme(context),
                onTap: () => AppLauncher.openEmail(
                  to: AppConfig.developerEmail,
                  subject: AboutConstants.contactSubject,
                ),
              ),
              verticalSpacing(20),

              // ── Support ───────────────────────────────────────────
              AboutSectionLabel('about.sections.support'.tr()),
              verticalSpacing(12),
              AboutFlatRow(
                icon: Icons.star_outline_rounded,
                label: 'about.support.rate_app'.tr(),
                // onTap: () => switchLanguage(context)
                onTap: () => AppLauncher.openStore(
                  androidUrl: AboutConstants.androidStoreUrl,
                  iosUrl: AboutConstants.iosStoreUrl,
                  isIos: isIos,
                ),
              ),
              AboutFlatRow(
                icon: Icons.bug_report_outlined,
                label: 'about.support.report_bug'.tr(),
                onTap: () => AppLauncher.openEmail(
                  to: AppConfig.developerEmail,
                  subject: AboutConstants.bugReportSubject,
                  body: AboutConstants.bugReportBody,
                ),
              ),
              AboutFlatRow(
                icon: Icons.mail_outline_rounded,
                label: 'about.support.contact_us'.tr(),
                onTap: () => AppLauncher.openEmail(
                  to: AppConfig.developerEmail,
                  subject: AboutConstants.contactSubject,
                ),
                showDivider: false,
              ),
              verticalSpacing(20),

              // ── Legal ─────────────────────────────────────────────
              AboutSectionLabel('about.sections.legal'.tr()),
              verticalSpacing(12),
              AboutFlatRow(
                icon: Icons.privacy_tip_outlined,
                label: 'about.legal.privacy_policy'.tr(),
                onTap: () => AppLauncher.openUrl(
                  AboutConstants.privacyPolicyUrl,
                ),
              ),
              AboutFlatRow(
                icon: Icons.description_outlined,
                label: 'about.legal.terms_of_service'.tr(),
                onTap: () => AppLauncher.openUrl(
                  AboutConstants.termsOfServiceUrl,
                ),
              ),
              AboutFlatRow(
                icon: Icons.article_outlined,
                label: 'about.legal.open_source_licenses'.tr(),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConfig.appName,
                  applicationVersion: AppConfig.appVersion,
                ),
                showDivider: false,
              ),
              verticalSpacing(32),

              // ── Footer ────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      '© $_currentYear ${AppConfig.appName}',
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textHint,
                      ),
                    ),
                    verticalSpacing(4),
                    Text(
                      '${'about.footer.made_with_love'.tr()} ${AppConfig.developerName}',
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              verticalSpacing(32),
            ],
          ),
        ),
      ),
    );
  }

  String get _currentYear => DateTime.now().year.toString();
}
