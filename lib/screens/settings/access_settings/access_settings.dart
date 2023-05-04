import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:adguard_home_manager/screens/settings/access_settings/clients_list.dart';

import 'package:adguard_home_manager/constants/enums.dart';
import 'package:adguard_home_manager/services/http_requests.dart';
import 'package:adguard_home_manager/providers/app_config_provider.dart';
import 'package:adguard_home_manager/providers/servers_provider.dart';

class AccessSettings extends StatelessWidget {
  const AccessSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    return AccessSettingsWidget(
      serversProvider: serversProvider,
      appConfigProvider: appConfigProvider,
    );
  }
}

class AccessSettingsWidget extends StatefulWidget {
  final ServersProvider serversProvider;
  final AppConfigProvider appConfigProvider;

  const AccessSettingsWidget({
    Key? key,
    required this.serversProvider,
    required this.appConfigProvider,
  }) : super(key: key);

  @override
  State<AccessSettingsWidget> createState() => _AccessSettingsWidgetState();
}

class _AccessSettingsWidgetState extends State<AccessSettingsWidget> with TickerProviderStateMixin {
  final ScrollController scrollController = ScrollController();
  late TabController tabController;

  Future fetchClients() async {
    widget.serversProvider.setClientsLoadStatus(LoadStatus.loading, false);
    final result = await getClients(widget.serversProvider.selectedServer!);
    if (mounted) {
      if (result['result'] == 'success') {
        widget.serversProvider.setClientsData(result['data']);
        widget.serversProvider.setClientsLoadStatus(LoadStatus.loaded, true);
      }
      else {
        widget.appConfigProvider.addLog(result['log']);
        widget.serversProvider.setClientsLoadStatus(LoadStatus.error, true);
      }
    }
  }


  @override
  void initState() {
    fetchClients();
    super.initState();
    tabController = TabController(
      initialIndex: 0,
      length: 3,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);

    Widget body() {
      return TabBarView(
        controller: tabController,
        children: [
          ClientsList(
            type: 'allowed',
            scrollController: scrollController, 
            loadStatus: serversProvider.clients.loadStatus, 
            data: serversProvider.clients.loadStatus == LoadStatus.loaded
              ? serversProvider.clients.data!.clientsAllowedBlocked!.allowedClients : [], 
            fetchClients: fetchClients
          ),
          ClientsList(
            type: 'disallowed',
            scrollController: scrollController, 
            loadStatus: serversProvider.clients.loadStatus, 
            data: serversProvider.clients.loadStatus == LoadStatus.loaded
              ? serversProvider.clients.data!.clientsAllowedBlocked!.disallowedClients : [], 
            fetchClients: fetchClients
          ),
          ClientsList(
            type: 'domains',
            scrollController: scrollController, 
            loadStatus: serversProvider.clients.loadStatus, 
            data: serversProvider.clients.loadStatus == LoadStatus.loaded
              ? serversProvider.clients.data!.clientsAllowedBlocked!.blockedHosts : [], 
            fetchClients: fetchClients
          ),
        ]
      );
    }

    PreferredSizeWidget tabBar() {
      return TabBar(
        controller: tabController,
        isScrollable: true,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        tabs: [
          Tab(
            child: Row(
              children: [
                const Icon(Icons.check),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.allowedClients)
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.block),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.disallowedClients)
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.link_rounded),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.disallowedDomains)
              ],
            ),
          ),
        ]
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      return Scaffold(
        body: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            controller: scrollController,
            headerSliverBuilder: ((context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverSafeArea(
                    top: false,
                    sliver: SliverAppBar(
                      title: Text(AppLocalizations.of(context)!.accessSettings),
                      pinned: true,
                      floating: true,
                      centerTitle: false,
                      forceElevated: innerBoxIsScrolled,
                      bottom: tabBar()
                    ),
                  ),
                )
              ];
            }), 
            body: body()
          )
        ),
      );
    }
    else {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.accessSettings),
          centerTitle: false,
          bottom: tabBar()
        ),
        body: body(),
      );
    }
  }
}