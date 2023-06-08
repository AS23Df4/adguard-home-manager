import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:adguard_home_manager/models/server.dart';
import 'package:adguard_home_manager/models/update_available.dart';
import 'package:adguard_home_manager/services/http_requests.dart';
import 'package:adguard_home_manager/functions/conversions.dart';
import 'package:adguard_home_manager/services/db/queries.dart';
import 'package:adguard_home_manager/functions/compare_versions.dart';
import 'package:adguard_home_manager/constants/enums.dart';

class ServersProvider with ChangeNotifier {
  Database? _dbInstance;

  List<Server> _serversList = [];
  Server? _selectedServer;
  ApiClient? _apiClient;

  final UpdateAvailable _updateAvailable = UpdateAvailable(
    loadStatus: LoadStatus.loading,
    data: null,
  );

  ApiClient? get apiClient {
    return _apiClient;
  }

  List<Server> get serversList {
    return _serversList;
  }

  Server? get selectedServer {
    return _selectedServer;
  }

  UpdateAvailable get updateAvailable {
    return _updateAvailable;
  }

  void setDbInstance(Database db) {
    _dbInstance = db;
  }

  void addServer(Server server) {
    _serversList.add(server);
    notifyListeners();
  }

  void setSelectedServer(Server server) {
    _selectedServer = server;
    notifyListeners();
  }

  void setUpdateAvailableLoadStatus(LoadStatus status, bool notify) {
    _updateAvailable.loadStatus = status;
    if (notify == true) {
      notifyListeners();
    }
  }

  void setUpdateAvailableData(UpdateAvailableData data) {
    _updateAvailable.data = data;
    notifyListeners();
  }

  void setApiClient(ApiClient client) {
    _apiClient = client;
    notifyListeners();
  }

  Future<dynamic> createServer(Server server) async {
    final saved = await saveServerQuery(_dbInstance!, server);
    if (saved == null) {
      if (server.defaultServer == true) {
        final defaultServer = await setDefaultServer(server);
        if (defaultServer == null) {
          _serversList.add(server);
          notifyListeners();
          return null;
        }
        else {
          return defaultServer;
        }
      }
      else {
        _serversList.add(server);
        notifyListeners();
        return null;
      }
    }
    else {
      return saved;
    }
  }

  Future<dynamic> setDefaultServer(Server server) async {
    final updated = await setDefaultServerQuery(_dbInstance!, server.id);
    if (updated == null) {
      List<Server> newServers = _serversList.map((s) {
        if (s.id == server.id) {
          s.defaultServer = true;
          return s;
        }
        else {
          s.defaultServer = false;
          return s;
        }
      }).toList();
      _serversList = newServers;
      notifyListeners();
      return null;
    }
    else {
      return updated;
    }
  }

  Future<dynamic> editServer(Server server) async {
    final result = await editServerQuery(_dbInstance!, server);
    if (result == null) {
      List<Server> newServers = _serversList.map((s) {
        if (s.id == server.id) {
          return server;
        }
        else {
          return s;
        }
      }).toList();
      _serversList = newServers;

      if (selectedServer != null &&server.id == selectedServer!.id) {
        _apiClient = ApiClient(server: server);
      }

      notifyListeners();
      return null;
    }
    else {
      return result;
    }
  }

  Future<bool> removeServer(Server server) async {
    final result = await removeServerQuery(_dbInstance!, server.id);
    if (result == true) {
      _selectedServer = null;
      _apiClient = null;
      List<Server> newServers = _serversList.where((s) => s.id != server.id).toList();
      _serversList = newServers;
      notifyListeners();
      return true;
    }
    else {
      return false;
    }
  }

  void checkServerUpdatesAvailable({
    required Server server, 
    bool? setValues
  }) async {
    if (setValues == true) setUpdateAvailableLoadStatus(LoadStatus.loading, true);
    final result = await _apiClient!.checkServerUpdates();
    if (result['result'] == 'success') {
      UpdateAvailableData data = UpdateAvailableData.fromJson(result['data']);
      final gitHubResult = await _apiClient!.getUpdateChangelog(releaseTag: data.newVersion ?? data.currentVersion);
      if (gitHubResult['result'] == 'success') {
        data.changelog = gitHubResult['body'];
      }
      data.updateAvailable = data.newVersion != null 
        ? compareVersions(
            currentVersion: data.currentVersion,
            newVersion: data.newVersion!,
          )
        : false;
      if (setValues == true) {
        setUpdateAvailableData(data);
      }
      else {
        if (data.currentVersion == data.newVersion) setUpdateAvailableData(data);
      }
      if (setValues == true) setUpdateAvailableLoadStatus(LoadStatus.loaded, true);
    }
    else {
      if (setValues == true) setUpdateAvailableLoadStatus(LoadStatus.error, true);
    }
  }

  void clearUpdateAvailable(Server server, String newCurrentVersion) {
    if (_updateAvailable.data != null) {
      _updateAvailable.data!.updateAvailable = null;
      _updateAvailable.data!.currentVersion = newCurrentVersion;
      notifyListeners();
    }
  }

  Future initializateServer(Server server) async {
    final serverStatus = await _apiClient!.getServerStatus();
    if (serverStatus['result'] == 'success') {
      checkServerUpdatesAvailable(
        server: server,
        setValues: true
      ); // Do not await
    }
  }

  Future saveFromDb(List<Map<String, dynamic>>? data) async {
    if (data != null) {
      Server? defaultServer;
      for (var server in data) {
        final Server serverObj = Server(
          id: server['id'],
          name: server['name'],
          connectionMethod: server['connectionMethod'],
          domain: server['domain'],
          path: server['path'],
          port: server['port'],
          user: server['user'],
          password: server['password'],
          defaultServer: convertFromIntToBool(server['defaultServer'])!,
          authToken: server['authToken'],
          runningOnHa: convertFromIntToBool(server['runningOnHa'])!,
        );
        _serversList.add(serverObj);
        if (convertFromIntToBool(server['defaultServer']) == true) {
          defaultServer = serverObj;
        }
      }

      notifyListeners();

      if (defaultServer != null) {
        _selectedServer = defaultServer;
        _apiClient = ApiClient(server: defaultServer);
        initializateServer(defaultServer);
      }
    }
    else {
      notifyListeners();
      return null;
    }
  }

  void recheckPeriodServerUpdated() {
    if (_selectedServer != null) {
      Server server = _selectedServer!;
      Timer.periodic(
        const Duration(seconds: 2), 
        (timer) {
          if (_selectedServer != null && _selectedServer == server) {
            checkServerUpdatesAvailable(server: server, setValues: false);
          }
          else {
            timer.cancel();
          }
        }
      );
    }
  }
}