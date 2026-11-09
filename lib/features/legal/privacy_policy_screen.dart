import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_widgets.dart';

/// In-app privacy policy (Bengali). Reachable without signing in.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _name = AppConstants.appName;

  static final _sections = <_Section>[
    const _Section('১. আমরা কী কী তথ্য সংগ্রহ করি', [
      _Sub('ক) আপনার অ্যাকাউন্টের তথ্য'),
      _Bullet('নাম'),
      _Bullet('ইমেইল ঠিকানা'),
      _Bullet(
        'পাসওয়ার্ড (পাসওয়ার্ড আমরা দেখতে পাই না; এটি Google Firebase এনক্রিপ্ট করে রাখে)',
      ),
      _Bullet('আপনার ভূমিকা (মালিক বা স্টাফ) এবং কোন দোকানের সাথে যুক্ত'),
      _Sub('খ) দোকানের তথ্য'),
      _Bullet('দোকানের নাম, ইনভাইট কোড এবং দোকানের সেটিংস'),
      _Bullet('স্টাফদের নাম ও ইমেইল (মালিক যাদের দোকানে যুক্ত করেন)'),
      _Sub('গ) হিসাবের তথ্য (যা আপনি নিজে লেখেন)'),
      _Bullet('বিক্রি: পণ্যের নাম, দাম, লাভ, নগদ বা ডিজিটাল পেমেন্ট'),
      _Bullet('খরচ: খাত, উপখাত, পরিমাণ, নোট'),
      _Bullet('জমা, রিটার্ন, ওপেনিং ক্যাশ ও দিন শেষের হিসাব'),
      _Bullet('পণ্যের তালিকা ও খরচের খাতের তালিকা'),
      _Bullet('প্রতিটি এন্ট্রি কে এবং কখন করেছেন'),
      _Sub('ঘ) কাস্টমারের তথ্য (বাকির খাতা)'),
      _Bullet('কাস্টমারের নাম ও ফোন নম্বর (ঐচ্ছিক)'),
      _Bullet('বাকির পরিমাণ, আদায়ের পরিমাণ ও তারিখ'),
      _Para(
        'এই তথ্য আপনি (দোকানের মালিক বা স্টাফ) নিজে অ্যাপে লেখেন। কাস্টমারের নাম ও ফোন নম্বর রাখার আগে প্রয়োজনে কাস্টমারের সম্মতি নেওয়া আপনার দায়িত্ব।',
      ),
      _Sub('ঙ) ফোনে সংরক্ষিত তথ্য'),
      _Bullet('ভাষা, থিম ও ড্যাশবোর্ডের পছন্দ আপনার ফোনেই সংরক্ষিত থাকে।'),
      _Bullet(
        'ইন্টারনেট না থাকলেও অ্যাপ চালু রাখার জন্য আপনার হিসাবের একটি কপি ফোনে (অফলাইন ক্যাশ) রাখা হয়।',
      ),
      _Sub('আমরা যা সংগ্রহ করি না'),
      _Bullet('আপনার অবস্থান (লোকেশন)'),
      _Bullet('ফোনের কন্টাক্ট লিস্ট, ছবি বা ফাইল'),
      _Bullet('ব্যাংক কার্ড বা বিকাশের পিন/পাসওয়ার্ড'),
      _Bullet('কোনো বিজ্ঞাপনের তথ্য; অ্যাপে কোনো বিজ্ঞাপন নেই'),
    ]),
    const _Section('২. তথ্য কেন ব্যবহার করি', [
      _Bullet('আপনার দোকানের হিসাব রাখা, দেখানো ও রিপোর্ট তৈরি করা'),
      _Bullet('লগইন করানো এবং আপনার অ্যাকাউন্ট সুরক্ষিত রাখা'),
      _Bullet('মালিক ও স্টাফদের একই দোকানের হিসাব একসাথে দেখার সুযোগ দেওয়া'),
      _Bullet('একাধিক ফোনে হিসাব মিলিয়ে রাখা (সিঙ্ক)'),
      _Bullet('আপনার অনুরোধে সাপোর্ট দেওয়া'),
      _Para('আপনার তথ্য অন্য কোনো উদ্দেশ্যে ব্যবহার করা হয় না।'),
    ]),
    const _Section('৩. তথ্য কোথায় ও কীভাবে সংরক্ষিত থাকে', [
      _Bullet(
        'সব তথ্য Google Firebase (Firebase Authentication ও Cloud Firestore)-এ সংরক্ষিত থাকে। এটি Google-এর নিরাপদ ক্লাউড সার্ভার।',
      ),
      _Bullet(
        'অ্যাপ আর সার্ভারের মধ্যে আদান-প্রদান হওয়া সব তথ্য এনক্রিপ্টেড (HTTPS) থাকে।',
      ),
      _Bullet(
        'নিরাপত্তা নিয়ম অনুযায়ী, শুধু আপনার দোকানের সক্রিয় সদস্যরাই সেই দোকানের হিসাব দেখতে পারেন। অন্য কোনো দোকান বা ব্যবহারকারী আপনার তথ্য দেখতে পারে না।',
      ),
      _Bullet('দোকানের মালিক যেকোনো স্টাফের অ্যাক্সেস বন্ধ করতে পারেন।'),
      _Bullet(
        'অ্যাপের লেখার ফন্ট Google Fonts থেকে লোড হয়। এতে আপনার হিসাবের কোনো তথ্য যায় না।',
      ),
    ]),
    const _Section('৪. তথ্য বিক্রি বা শেয়ার', [
      _Bullet('আমরা আপনার কোনো তথ্য বিক্রি করি না।', strong: true),
      _Bullet('বিজ্ঞাপন বা মার্কেটিংয়ের জন্য কারও সাথে তথ্য শেয়ার করি না।'),
      _Bullet('তথ্য সংরক্ষণের জন্য শুধু Google Firebase ব্যবহার করা হয়।'),
      _Bullet(
        'আইনগতভাবে বাধ্য হলে (যেমন আদালতের আদেশে) শুধু প্রয়োজনীয় তথ্য দেওয়া হতে পারে।',
      ),
      _Bullet(
        'আপনি নিজে "রিপোর্ট শেয়ার" করলে, অথবা কাস্টমারকে WhatsApp/SMS-এ রিমাইন্ডার পাঠালে, সেই বার্তা আপনার ফোনের অ্যাপ দিয়ে আপনিই পাঠান। অ্যাপ নিজে থেকে কাউকে কিছু পাঠায় না।',
      ),
    ]),
    const _Section('৫. তথ্য কতদিন রাখা হয়', [
      _Para(
        'যতদিন আপনার অ্যাকাউন্ট ও দোকান সক্রিয় থাকে, ততদিন আপনার হিসাব সংরক্ষিত থাকে, যাতে আপনি পুরোনো হিসাব দেখতে পারেন। অ্যাকাউন্ট মুছে ফেললে নিচের নিয়ম অনুযায়ী তথ্য মুছে যায়।',
      ),
    ]),
    const _Section('৬. তথ্য মুছে ফেলা ও আপনার অধিকার', [
      _Bullet(
        'এন্ট্রি মুছতে: অ্যাপের ভেতরেই যেকোনো বিক্রি, খরচ, বাকি বা অন্য এন্ট্রি মুছে ফেলতে পারবেন।',
      ),
      _Bullet(
        'অ্যাকাউন্ট মুছতে: অ্যাপে "আরও → প্রোফাইল → অ্যাকাউন্ট মুছুন" চাপুন এবং পাসওয়ার্ড দিয়ে নিশ্চিত করুন। সাথে সাথেই অ্যাকাউন্ট ও সংশ্লিষ্ট তথ্য স্থায়ীভাবে মুছে যাবে।',
        strong: true,
      ),
      _Bullet(
        'দোকানের মালিক অ্যাকাউন্ট মুছলে সেই দোকানের সব হিসাব মুছে যাবে, স্টাফদের এন্ট্রিসহ। স্টাফরা আর সেই দোকানে ঢুকতে পারবেন না।',
      ),
      _Bullet(
        'স্টাফ অ্যাকাউন্ট মুছলে শুধু সেই স্টাফের অ্যাকাউন্ট মুছবে। তাদের লেখা হিসাব দোকানের রেকর্ডে থেকে যাবে।',
      ),
      _Bullet(
        'অ্যাপে ঢুকতে না পারলে, আপনার নিবন্ধিত ইমেইল থেকে নিচের যোগাযোগ ঠিকানায় "অ্যাকাউন্ট মুছে ফেলার অনুরোধ" লিখে পাঠান। পরিচয় নিশ্চিত হওয়ার পর ৩০ দিনের মধ্যে মুছে ফেলা হবে।',
      ),
      _Bullet(
        'আপনার তথ্যের একটি কপি চাইলে, বা কোনো তথ্য সংশোধন করতে চাইলে, আমাদের সাথে যোগাযোগ করুন।',
      ),
      _Bullet(
        'কোনো কাস্টমার নিজের নাম বা ফোন নম্বর মুছতে চাইলে সংশ্লিষ্ট দোকানকে জানাতে পারেন। দোকান অ্যাপ থেকেই তা মুছে দিতে পারবে।',
      ),
    ]),
    const _Section('৭. শিশুদের গোপনীয়তা', [
      _Para(
        'এই অ্যাপ দোকান ও ব্যবসা পরিচালনার জন্য তৈরি। ১৩ বছরের কম বয়সী শিশুদের জন্য নয়। আমরা জেনেশুনে শিশুদের কোনো তথ্য সংগ্রহ করি না।',
      ),
    ]),
    const _Section('৮. নীতিতে পরিবর্তন', [
      _Para(
        'এই নীতি সময়ের সাথে হালনাগাদ হতে পারে। বড় কোনো পরিবর্তন হলে অ্যাপের ভেতরে জানানো হবে। উপরের "সর্বশেষ হালনাগাদ" তারিখ দেখে বুঝবেন কবে বদলেছে।',
      ),
    ]),
    _Section('৯. যোগাযোগ', [
      const _Para(
        'গোপনীয়তা, তথ্য মুছে ফেলা বা অন্য কোনো প্রশ্নে যোগাযোগ করুন:',
      ),
      if (AppConstants.developerName.isNotEmpty)
        const _Bullet('ডেভেলপার: ${AppConstants.developerName}'),
      if (AppConstants.supportEmail.isNotEmpty)
        const _Bullet('ইমেইল: ${AppConstants.supportEmail}'),
      if (AppConstants.supportPhone.isNotEmpty)
        const _Bullet('ফোন / WhatsApp: ${AppConstants.supportPhone}'),
      if (AppConstants.supportAddress.isNotEmpty)
        const _Bullet('ঠিকানা: ${AppConstants.supportAddress}'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                ScreenHeader(
                  title: 'গোপনীয়তা নীতি',
                  subtitle: _name,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/login'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(context, radius: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'সর্বশেষ হালনাগাদ: ${AppConstants.privacyPolicyUpdated}',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"$_name" ("অ্যাপ", "আমরা") দোকানের দৈনিক বিক্রি, খরচ, জমা, রিটার্ন ও বাকির হিসাব রাখার একটি অ্যাপ। আপনার ও আপনার দোকানের তথ্য আমাদের কাছে গুরুত্বপূর্ণ। এই নীতিতে বলা আছে আমরা কী তথ্য রাখি, কেন রাখি, কোথায় রাখি এবং আপনি কীভাবে তা মুছে ফেলতে পারেন। অ্যাপ ব্যবহার করলে আপনি এই নীতিতে সম্মত হচ্ছেন বলে ধরা হবে।',
                        style: textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                for (final section in _sections) ...[
                  const SizedBox(height: 14),
                  _SectionCard(section: section),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final List<_Block> blocks;

  const _Section(this.title, this.blocks);
}

sealed class _Block {
  const _Block();
}

class _Sub extends _Block {
  final String text;
  const _Sub(this.text);
}

class _Para extends _Block {
  final String text;
  const _Para(this.text);
}

class _Bullet extends _Block {
  final String text;
  final bool strong;
  const _Bullet(this.text, {this.strong = false});
}

class _SectionCard extends StatelessWidget {
  final _Section section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final body = textTheme.bodyMedium?.copyWith(height: 1.6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final block in section.blocks)
            switch (block) {
              _Sub(:final text) => Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  text,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              _Para(:final text) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(text, style: body),
              ),
              _Bullet(:final text, :final strong) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: body),
                    Expanded(
                      child: Text(
                        text,
                        style: strong
                            ? body?.copyWith(fontWeight: FontWeight.w700)
                            : body,
                      ),
                    ),
                  ],
                ),
              ),
            },
        ],
      ),
    );
  }
}
