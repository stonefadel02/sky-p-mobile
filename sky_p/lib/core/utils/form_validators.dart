// lib/core/utils/form_validators.dart

class FormValidators {
  
  // ── NOM / PRÉNOM ──────────────────────────────────────────
  static String? nom(String? v) {
    if (v == null || v.trim().isEmpty) return "Le nom est obligatoire";
    if (v.trim().length < 2) return "Le nom doit contenir au moins 2 caractères";
    return null;
  }

  static String? prenom(String? v) {
    if (v == null || v.trim().isEmpty) return "Le prénom est obligatoire";
    if (v.trim().length < 2) return "Le prénom doit contenir au moins 2 caractères";
    return null;
  }

  // ── TÉLÉPHONE ─────────────────────────────────────────────
  static String? telephone(String? v) {
    if (v == null || v.trim().isEmpty) return "Le numéro de téléphone est obligatoire";
    
    final cleaned = v.trim().replaceAll(' ', '').replaceAll('-', '');
    
    // Accepte : 97000000 OU +22997000000
    final regex = RegExp(r'^(\+229)?01[0-9]{8}$');
    if (!regex.hasMatch(cleaned)) {
      return "Numéro invalide — ex: 01 97 00 00 00";
    }
    return null;
  }

  // ── EMAIL ─────────────────────────────────────────────────
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return "L'email est obligatoire";
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(v.trim())) return "Format invalide — ex: nom@email.com";
    return null;
  }

  // ── IFU ───────────────────────────────────────────────────
  static String? ifu(String? v) {
    if (v == null || v.trim().isEmpty) return "L'IFU est obligatoire";
    if (!RegExp(r'^\d{13}$').hasMatch(v.trim())) {
      return "L'IFU doit contenir exactement 13 chiffres";
    }
    return null;
  }

  // ── RCCM ──────────────────────────────────────────────────
  static String? rccm(String? v) {
    if (v == null || v.trim().isEmpty) return "Le RCCM est obligatoire";
    if (v.trim().length < 3) return "RCCM invalide";
    return null;
  }

  // ── STRUCTURE ─────────────────────────────────────────────
  static String? structure(String? v) {
    if (v == null || v.trim().isEmpty) return "La structure est obligatoire";
    return null;
  }

  // ── MOT DE PASSE ──────────────────────────────────────────
  static String? motDePasse(String? v) {
    if (v == null || v.isEmpty) return "Le mot de passe est obligatoire";
    if (v.length < 6) return "Minimum 6 caractères requis";
    return null;
  }

  // ── CONFIRMATION MOT DE PASSE ─────────────────────────────
  static String? Function(String?) confirmerMotDePasse(String motDePasse) {
    return (String? v) {
      if (v == null || v.isEmpty) return "Veuillez confirmer votre mot de passe";
      if (v != motDePasse) return "Les mots de passe ne correspondent pas";
      return null;
    };
  }

  // ── CHAMP GÉNÉRIQUE NON VIDE ──────────────────────────────
  static String? Function(String?) requis(String nomDuChamp) {
    return (String? v) {
      if (v == null || v.trim().isEmpty) return "$nomDuChamp est obligatoire";
      return null;
    };
  }
}