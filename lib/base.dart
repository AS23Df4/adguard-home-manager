// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:store_checker/store_checker.dart';
import 'package:flutter/services.dart';

import 'package:adguard_home_manager/widgets/bottom_nav_bar.dart';
import 'package:adguard_home_manager/widgets/menu_bar.dart';
import 'package:adguard_home_manager/widgets/update_modal.dart';
import 'package:adguard_home_manager/widgets/navigation_rail.dart';

import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/models/github_release.dart';
import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/services/http_requests.dart';
import 'package:adguard_home_manager/models/app_screen.dart';
import 'package:adguard_home_manager/config/app_screens.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class Base extends StatefulWidget {
  final AppConfigProvider appConfigProvider;

  const Base({
    Key? key,
    required this.appConfigProvider,
  }) : super(key: key);

  @override
  State<Base> createState() => _BaseState();
}

class _BaseState extends State<Base> with WidgetsBindingObserver {
  int selectedScreen = 0;

  bool updateExists(String appVersion, String gitHubVersion) {
    final List<int> appVersionSplit = List<int>.from(appVersion.split('.').map((e) => int.parse(e)));
    final List<int> gitHubVersionSplit = List<int>.from(gitHubVersion.split('.').map((e) => int.parse(e)));

    if (gitHubVersionSplit[0] > appVersionSplit[0]) {
      return true;
    }
    else if (gitHubVersionSplit[0] ==  appVersionSplit[0] && gitHubVersionSplit[1] > appVersionSplit[1]) {
      return true;
    }
    else if (gitHubVersionSplit[0] ==  appVersionSplit[0] && gitHubVersionSplit[1] == appVersionSplit[1] && gitHubVersionSplit[2] > appVersionSplit[2]) {
      return true;
    }
    else {
      return false;
    }
  }

  Future<GitHubRelease?> checkInstallationSource() async {
    final result = await checkAppUpdatesGitHub();
    if (result['result'] == 'success') {
      final update = updateExists(widget.appConfigProvider.getAppInfo!.version, result['body'].tagName);
      if (update == true) {
        if (Platform.isAndroid) {
          Source installationSource = await StoreChecker.getSource;
          if (installationSource == Source.IS_INSTALLED_FROM_PLAY_STORE) {
            return null;
          }
          else {
            return result['body'];
          }
        }
        else if (Platform.isIOS) {
          return null;
        }
        else {
          return result['body'];
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await checkInstallationSource();

      if (result != null && widget.appConfigProvider.doNotRememberVersion != result.tagName) {
        await showDialog(
          context: context, 
          builder: (context) => UpdateModal(
            gitHubRelease: result,
            onDownload: (link, version) => openUrl(link),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    final width = MediaQuery.of(context).size.width;

    List<AppScreen> screens = serversProvider.selectedServer != null
      ? screensServerConnected 
      : screensSelectServer;

    if (kDebugMode && dotenv.env['ENABLE_SENTRY'] == "true") {
      Sentry.captureException("Debug mode", stackTrace: {
        "aaa": "aaa"
      });
    }

    return CustomMenuBar(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Theme.of(context).brightness == Brightness.light
            ? Brightness.light
            : Brightness.dark,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
          systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
          systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        ),
        child: Scaffold(
          body: Row(
            children: [
              if (width > 900) const SideNavigationRail(),
                Expanded(
                  child: PageTransitionSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (
                      (child, primaryAnimation, secondaryAnimation) => FadeThroughTransition(
                        animation: primaryAnimation, 
                        secondaryAnimation: secondaryAnimation,
                        child: child,
                      )
                    ),
                    child: screens[appConfigProvider.selectedScreen].body,
                  ),
                ),
            ],
          ),
          bottomNavigationBar: width <= 900 
            ? const BottomNavBar()
            : null,
        )
      ),
    );
  }
}