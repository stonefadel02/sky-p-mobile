import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as dev;

import 'package:sky_p/services/header.dart';


class ExportService {
  static const Color igsBlue = Color(0xFF3473E4);

  Future<void> downloadExport(BuildContext context, String endpoint, String fileName) async {
    try {
      final file = await _downloadFile(endpoint, fileName);
      final result = await OpenFilex.open(file.path);
      
      if (result.type != ResultType.done) {
        throw Exception("Impossible d'ouvrir le fichier : ${result.message}");
      }

    } catch (e) {
      dev.log("Erreur Export", error: e, name: "IGS.Export");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ExportException
                  ? e.message
                  : "Le PDF n’a pas pu être téléchargé. Veuillez réessayer.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> shareExport(
    BuildContext context,
    String endpoint,
    String fileName,
    {
    String subject = 'Document PDF',
    String text = 'Voici le document PDF.',
    }
  ) async {
    try {
      final file = await _downloadFile(endpoint, fileName);
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(file.path)],
          subject: subject,
        ),
      );
    } catch (e) {
      dev.log("Erreur partage PDF", error: e, name: "IGS.Export");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'envoyer le PDF"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File> _downloadFile(String endpoint, String fileName) async {
    final header = await ApiHeaders.getHeaders();
    final tempDir = await getApplicationDocumentsDirectory();
    final savePath = "${tempDir.path}/$fileName.pdf";

    dev.log("Téléchargement de l'export : $endpoint", name: "IGS.Export");
    dev.log("Sauvegarde dans : $savePath", name: "IGS.Export");

    final response = await http.get(Uri.parse(endpoint), headers: header);
    dev.log(
      "Réponse export : ${response.statusCode}, ${response.bodyBytes.length} octets",
      name: "IGS.Export",
    );

    if (response.statusCode != 200) {
      throw ExportException(
        response.statusCode == 404
            ? 'Le PDF du chéquier est introuvable.'
            : 'Le PDF n’a pas pu être généré. Veuillez réessayer.',
      );
    }

    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes, flush: true);

    if (!await file.exists() || await file.length() == 0) {
      throw ExportException('Le fichier PDF reçu est vide.');
    }

    return file;
  }
}

class ExportException implements Exception {
  final String message;

  const ExportException(this.message);
}