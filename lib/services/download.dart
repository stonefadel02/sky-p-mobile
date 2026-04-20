import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:developer' as dev;

import 'package:sky_p/services/header.dart';


class ExportService {
  static const Color igsBlue = Color(0xFF3473E4);

  Future<void> downloadExport(BuildContext context, String endpoint, String fileName) async {
    try {
      final header = await ApiHeaders.getHeaders();

    
      final Directory tempDir = await getApplicationDocumentsDirectory();
      
      String savePath = "${tempDir.path}/$fileName.pdf";

      Dio dio = Dio();
      
      dev.log("Téléchargement de l'export : $endpoint", name: "IGS.Export");
      dev.log("Sauvegarde dans : $savePath", name: "IGS.Export");

      await dio.download(
        endpoint,
        savePath,
        options: Options(
          headers: header ,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            dev.log("Progression: ${(received / total * 100).toStringAsFixed(0)}%", name: "IGS.Export");
          }
        },
      );

      // 4. Ouverture du fichier
      final result = await OpenFilex.open(savePath);
      
      if (result.type != ResultType.done) {
        throw Exception("Impossible d'ouvrir le fichier : ${result.message}");
      }

    } catch (e) {
      dev.log("Erreur Export", error: e, name: "IGS.Export");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : ${e.toString().contains('404') ? 'Fichier non trouvé' : 'Échec de l\'exportation'}"), 
          backgroundColor: Colors.red
        ),
      );
    }
  }
}