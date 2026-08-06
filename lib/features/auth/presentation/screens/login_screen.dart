import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../cubit/session_cubit.dart';
import '../cubit/session_state.dart';

/// Supabase email/password login. Replaces the old "pick a file" empty
/// state as the app's entry point — see APP_PLAN.md decision #5.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.hideKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<SessionCubit>().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  String? _validateEmail(final String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'auth.login.email_required'.tr();
    if (!v.contains('@') || !v.contains('.')) {
      return 'auth.login.email_invalid'.tr();
    }
    return null;
  }

  String? _validatePassword(final String? value) {
    if ((value ?? '').isEmpty) return 'auth.login.password_required'.tr();
    return null;
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BlocConsumer<SessionCubit, SessionState>(
          listenWhen: (final SessionState previous, final SessionState current) =>
              previous.status != current.status || previous.errorMessage != current.errorMessage,
          listener: (final BuildContext context, final SessionState state) {
            if (state.isAuthenticated) {
              context.pushNamedAndRemoveAll(Routes.home);
              return;
            }
            if (state.errorMessage != null) {
              context.showErrorSnackBar(state.errorMessage!);
            }
          },
          builder: (final BuildContext context, final SessionState state) {
            final bool isLoading = state.status == SessionStatus.authenticating;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: rw(24)),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    verticalSpacing(80),
                    Center(
                      child: Text(
                        'holdings.home.brand'.tr(),
                        style: AppTextStyles.font24Bold.copyWith(
                          color: AppColors.primary200,
                        ),
                      ),
                    ),
                    verticalSpacing(8),
                    Center(
                      child: Text(
                        'auth.login.subtitle'.tr(),
                        style: AppTextStyles.font14Regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    verticalSpacing(48),
                    CustomTextForm(
                      hintText: 'auth.login.email_hint'.tr(),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      isRTL: context.isArabic,
                      validator: _validateEmail,
                      enabled: !isLoading,
                    ),
                    verticalSpacing(16),
                    CustomTextForm(
                      hintText: 'auth.login.password_hint'.tr(),
                      controller: _passwordController,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      isRTL: context.isArabic,
                      validator: _validatePassword,
                      enabled: !isLoading,
                    ),
                    verticalSpacing(28),
                    CustomTextButton(
                      text: 'auth.login.submit'.tr(),
                      onPressed: isLoading ? null : _submit,
                      isLoading: isLoading,
                      size: CustomButtonSize.large,
                    ),
                    verticalSpacing(24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
