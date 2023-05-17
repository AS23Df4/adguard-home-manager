// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:store_checker/store_checker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:adguard_home_manager/widgets/custom_list_tile.dart';

import 'package:adguard_home_manager/functions/open_url.dart';
import 'package:adguard_home_manager/functions/app_update_download_link.dart';
import 'package:adguard_home_manager/services/http_requests.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';

class GeneralSettings extends StatefulWidget {
  const GeneralSettings({Key? key}) : super(key: key);

  @override
  State<GeneralSettings> createState() => _GeneralSettingsState();
}

enum AppUpdatesStatus { available, checking, recheck }

class _GeneralSettingsState extends State<GeneralSettings> {
  AppUpdatesStatus appUpdatesStatus = AppUpdatesStatus.recheck;

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    Future updateHideZeroValues(bool newStatus) async {
      final result = await appConfigProvider.setHideZeroValues(newStatus);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsUpdatedSuccessfully),
            backgroundColor: Colors.green,
          )
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotUpdateSettings),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    Future updateShowNameTimeLogs(bool newStatus) async {
      final result = await appConfigProvider.setShowNameTimeLogs(newStatus);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsUpdatedSuccessfully),
            backgroundColor: Colors.green,
          )
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotUpdateSettings),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    Future checkUpdatesAvailable() async {
      setState(() => appUpdatesStatus = AppUpdatesStatus.checking);
      final result = await checkAppUpdatesGitHub();
      if (result['result'] == 'success') {
        final update = gitHubUpdateExists(appConfigProvider.getAppInfo!.version, result['body'].tagName);
        if (update == true) {
          appConfigProvider.setAppUpdatesAvailable(result['body']);
          setState(() => appUpdatesStatus = AppUpdatesStatus.available);
        }
        else {
          setState(() => appUpdatesStatus = AppUpdatesStatus.recheck);
        }
      }
      else {
        setState(() => appUpdatesStatus = AppUpdatesStatus.recheck);
      }
    }

    Widget generateAppUpdateStatus() {
      if (appUpdatesStatus == AppUpdatesStatus.available) {
        return IconButton(
          onPressed: appConfigProvider.appUpdatesAvailable != null
            ? () async {
                final link = getAppUpdateDownloadLink(appConfigProvider.appUpdatesAvailable!);
                if (link != null) {
                  openUrl(link);
                }
              }
            : null, 
          icon: const Icon(Icons.download_rounded),
          tooltip: AppLocalizations.of(context)!.downloadUpdate,
        );
      }
      else if (appUpdatesStatus == AppUpdatesStatus.checking) {
        return const Padding(
          padding: EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            )
          ),
        );
      }
      else {
        return IconButton(
          onPressed: checkUpdatesAvailable, 
          icon: const Icon(Icons.refresh_rounded),
          tooltip: AppLocalizations.of(context)!.checkUpdates,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.generalSettings),
        centerTitle: false,
      ),
      body: ListView(
        children: [
          CustomListTile(
            icon: Icons.exposure_zero_rounded,
            title: AppLocalizations.of(context)!.hideZeroValues,
            subtitle: AppLocalizations.of(context)!.hideZeroValuesDescription,
            trailing: Switch(
              value: appConfigProvider.hideZeroValues, 
              onChanged: updateHideZeroValues,
            ),
            onTap: () => updateHideZeroValues(!appConfigProvider.hideZeroValues),
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 16,
              right: 10
            )
          ),
          CustomListTile(
            icon: Icons.more,
            title: AppLocalizations.of(context)!.nameTimeLogs,
            subtitle: AppLocalizations.of(context)!.nameTimeLogsDescription,
            trailing: Switch(
              value: appConfigProvider.showNameTimeLogs, 
              onChanged: updateShowNameTimeLogs,
            ),
            onTap: () => updateShowNameTimeLogs(!appConfigProvider.showNameTimeLogs),
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 16,
              right: 10
            )
          ),
          if (
            !(Platform.isAndroid || Platform.isIOS) || 
            (Platform.isAndroid && (
              appConfigProvider.installationSource == Source.IS_INSTALLED_FROM_LOCAL_SOURCE) ||
              appConfigProvider.installationSource == Source.UNKNOWN
            )
          ) CustomListTile(
            icon: Icons.system_update_rounded,
            title: AppLocalizations.of(context)!.appUpdates,
            subtitle: appConfigProvider.appUpdatesAvailable != null
              ? AppLocalizations.of(context)!.updateAvailable
              : AppLocalizations.of(context)!.usingLatestVersion,
            trailing: generateAppUpdateStatus()
          )
        ],
      ),
    );  
  }
}