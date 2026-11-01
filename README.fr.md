<h1 align="center">🌀 Vent</h1>
<h3 align="center">Choisissez une température.<br>Laissez Vent gérer les ventilateurs.</h3>
<p align="center">Contrôle gratuit et open source des ventilateurs Mac. Directement dans votre barre des menus.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/badge/T%C3%A9l%C3%A9charger%20pour%20macOS-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Télécharger Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="Gratuit et open source"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=release" alt="Dernière version"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 ou version ultérieure">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="Licence MIT"></a>
</p>
<p align="center">
  <a href="#install">Commencer</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">Captures d’écran</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md"><strong>Français</strong></a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="Température cible, apparence claire">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="Température cible, apparence sombre">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ Votre température</strong><br><br>Choisissez une cible. Vent ajuste les ventilateurs.</td>
    <td align="center" width="33%"><strong>👁️ Avertissements visibles</strong><br><br>Repérez les vitesses élevées sans le son.</td>
    <td align="center" width="33%"><strong>💚 Tous les modes sont gratuits</strong><br><br>Pas d’abonnement. Pas de compte.</td>
  </tr>
</table>

## 🌡️ Votre température. Votre choix.

Vous ne devriez pas avoir à déterminer les RPM à utiliser chaque fois que votre charge de travail change. Choisissez une **température cible** dans **Auto Temp**, et Vent ajuste la vitesse des ventilateurs vers celle-ci. Vous pouvez aussi choisir un profil intégré et reprendre ce que vous faisiez.

> [!TIP]
> Le contrôle de la température est inclus. **Aucune offre payante, aucun abonnement, aucun compte.** Vent est un logiciel libre sous licence MIT.

| Ce que vous voulez | À choisir |
|---|---|
| Laisser macOS gérer le refroidissement | **Auto** |
| Laisser Vent ajuster les ventilateurs vers une température | **Auto Temp** |
| Définir vous-même des RPM exacts | **Manual RPM**, ensemble ou ventilateur par ventilateur |
| Passer rapidement d’une configuration enregistrée à une autre | **Quiet**, **Normal**, **Gaming**, **Lap** ou votre propre profil |

Une température cible est un objectif, pas une garantie : le résultat dépend de votre Mac, de la charge de travail et de l’environnement. Vent utilise les relevés des capteurs disponibles ; la température affichée ne mesure ni le boîtier ni votre peau.

## 👁️ Voyez quand les ventilateurs peuvent être bruyants

**Vous n’avez pas besoin d’entendre les ventilateurs pour savoir qu’ils tournent fort.** Vent affiche un avertissement visible dans son panneau lorsque les vitesses des ventilateurs sont élevées. C’est particulièrement utile aux personnes sourdes ou malentendantes, ainsi qu’à toute personne portant un casque.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent affiche un avertissement textuel orange : ventilateurs à 85 % — peuvent être bruyants">
</p>

L’avertissement estime le bruit possible à partir des RPM : il apparaît lorsque la vitesse actuelle du ventilateur le plus rapide atteint 70 % de la vitesse maximale la plus élevée signalée. **Il n’utilise pas de microphone et ne mesure pas les décibels.**

Vous pouvez aussi activer **Notify when fans are loud** dans Settings et autoriser les notifications macOS. Dans l’implémentation actuelle, les relevés se mettent à jour lorsque le panneau Vent est visible ; ne vous fiez pas à cette option comme à une alerte sonore permanente en arrière-plan.

## ✨ Petite app, commandes utiles

- Un panneau compact dans la barre des menus, adapté aux apparences système claire et sombre. Aucune icône dans le Dock.
- Température et vitesses des ventilateurs en direct, avec des commandes RPM fondées sur les limites matérielles signalées.
- Profils intégrés, avec possibilité d’enregistrer, renommer et supprimer les vôtres.
- Celsius ou Fahrenheit, lancement à l’ouverture de session et vérifications de mise à jour configurables.
- Un helper local qui continue de contrôler les ventilateurs lorsque le panneau ou l’app est fermé.
- `ventctl` pour les scripts et le diagnostic. Consultez le [guide du développeur](docs/DEVELOPMENT.md).

<a id="install"></a>

## 🚀 Commencer

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### Télécharger

1. Téléchargez le DMG depuis [la dernière version](https://github.com/Fallet666/vent/releases/latest).
2. Faites glisser **Vent** vers **Applications**, puis ouvrez-le.
3. Suivez la configuration pour installer le helper. macOS demande un mot de passe administrateur, car modifier les vitesses des ventilateurs exige des privilèges élevés.
4. Choisissez **Auto Temp**, puis votre température cible — ou choisissez un profil.

Le packaging actuel utilise une signature ad hoc plutôt qu’une notarisation Developer ID ; macOS peut donc bloquer l’app téléchargée. Examinez le code source et la version avant de décider de l’autoriser dans les réglages de sécurité macOS.

**Nécessite macOS 13+ et un Mac avec des ventilateurs contrôlables.** Le projet prend en charge Intel et Apple Silicon, mais la disponibilité des capteurs et le contrôle des ventilateurs varient selon les modèles. Un MacBook Air sans ventilateur n’a pas de ventilateur à contrôler. Veuillez [signaler la compatibilité](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml) plutôt que de supposer que tous les modèles sont pris en charge.

## ↩️ Revenir au contrôle de macOS

> [!IMPORTANT]
> **Fermer le panneau ou quitter Vent ne réinitialise pas les réglages des ventilateurs.** Sélectionnez **Auto** avant de quitter si vous voulez que macOS reprenne la main.

Le helper `ventd` installé continue de fonctionner après la fermeture de l’app. Settings propose aussi **Uninstall Helper**, qui remet les ventilateurs sur Auto et supprime le helper. Supprimez l’app séparément si vous n’en avez plus besoin.

## 🔒 Confidentialité

Pas de compte ni d’analytique. Le contrôle des ventilateurs s’effectue localement via un socket Unix entre l’app et `ventd`.

**Les vérifications automatiques de mise à jour sont activées par défaut** et contactent GitHub pour obtenir les informations de version. Le téléchargement d’une mise à jour utilise également le réseau. Désactivez **Automatically check for updates** dans Settings si vous ne voulez pas de vérifications automatiques.

## 💚 Aidez Vent à atteindre plus de Macs

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Ajouter une étoile à Vent sur GitHub"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Envoyer un rapport de compatibilité"></a>
</p>

Si Vent vous est utile, ajoutez une étoile au dépôt, partagez-le avec quelqu’un qui en a besoin ou envoyez un rapport de compatibilité. Les signalements de bugs, les traductions et les pull requests sont également utiles.

Lorsque vous signalez un problème matériel, indiquez le modèle de votre Mac, la version de macOS, ce que vous attendiez et la sortie de :

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ Compiler et contribuer

Instructions de build, exemples CLI et architecture : [guide du développeur](docs/DEVELOPMENT.md).

## Licence

[MIT](LICENSE). Utilisez-la, examinez-la et améliorez-la.
