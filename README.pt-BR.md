<h1 align="center">🌀 Vent</h1>
<h3 align="center">Escolha uma temperatura.<br>Deixe o Vent cuidar dos ventiladores.</h3>
<p align="center">Controle de ventiladores para Mac, gratuito e de código aberto. Bem na barra de menus.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/badge/Baixar%20para%20macOS-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Baixar o Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="Gratuito e de código aberto"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="Versão mais recente"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 ou posterior">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="Licença MIT"></a>
</p>
<p align="center">
  <a href="#install">Comece agora</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">Capturas de tela</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md"><strong>Português (Brasil)</strong></a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="Temperatura alvo, aparência clara">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="Temperatura alvo, aparência escura">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ Sua temperatura</strong><br><br>Escolha um alvo. O Vent ajusta os ventiladores.</td>
    <td align="center" width="33%"><strong>👁️ Avisos visíveis</strong><br><br>Perceba altas rotações dos ventiladores sem som.</td>
    <td align="center" width="33%"><strong>💚 Todos os modos são gratuitos</strong><br><br>Sem assinatura. Sem conta.</td>
  </tr>
</table>

## 🌡️ Sua temperatura. Sua escolha.

Você não precisa descobrir qual RPM usar sempre que sua carga de trabalho mudar. Escolha uma **temperatura alvo** em **Auto Temp**, e o Vent ajustará a velocidade dos ventiladores em direção a ela. Ou escolha um perfil integrado e volte ao que estava fazendo.

> [!TIP]
> O controle de temperatura está incluído. **Não há plano pago, assinatura nem conta.** Vent é software livre sob a licença MIT.

| O que você quer | O que escolher |
|---|---|
| Deixar o macOS gerenciar a refrigeração | **Auto** |
| Fazer o Vent ajustar os ventiladores em direção a uma temperatura | **Auto Temp** |
| Definir você mesmo o RPM exato | **Manual RPM**, em conjunto ou por ventilador |
| Alternar rapidamente entre configurações salvas | **Quiet**, **Normal**, **Gaming**, **Lap** ou seu próprio perfil |

Uma temperatura alvo é uma meta, não uma garantia: o resultado depende do seu Mac, da carga de trabalho e do ambiente ao redor. O Vent usa as leituras de sensores disponíveis; a temperatura exibida não é uma medição do gabinete nem da sua pele.

## 👁️ Veja quando os ventiladores podem estar barulhentos

**Você não precisa ouvir os ventiladores para saber que estão trabalhando forte.** O Vent mostra um aviso visível no painel quando as velocidades dos ventiladores estão altas. Isso é especialmente útil para pessoas surdas ou com deficiência auditiva e para quem usa fones de ouvido.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="O Vent mostra um aviso em texto laranja: ventiladores a 85% — podem estar barulhentos">
</p>

O aviso estima o possível ruído a partir do RPM: ele aparece quando a maior velocidade atual de um ventilador atinge 70% da maior velocidade máxima informada. **Ele não usa microfone nem mede decibéis.**

Você também pode ativar **Notify when fans are loud** em Settings e permitir notificações do macOS. Enquanto o aplicativo Vent estiver em execução, as leituras serão atualizadas mesmo com o painel fechado.

## ✨ Aplicativo pequeno, controles úteis

- Um painel compacto na barra de menus com aparência clara e escura do sistema. Sem ícone no Dock.
- Temperatura e velocidades dos ventiladores em tempo real, com controles de RPM baseados nos limites de hardware informados.
- Perfis integrados, além de salvar, renomear e excluir os seus próprios.
- Celsius ou Fahrenheit, inicialização ao iniciar sessão e verificações de atualização configuráveis.
- Um auxiliar local que preserva o modo escolhido ao fechar o painel; ao sair do aplicativo, os ventiladores voltam ao controle Auto do macOS.
- `ventctl` para scripts e diagnósticos. Consulte o [guia do desenvolvedor](docs/DEVELOPMENT.md).

<a id="install"></a>

## 🚀 Comece agora

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### Baixar

1. Baixe o DMG da [versão mais recente](https://github.com/Fallet666/vent/releases/latest).
2. Arraste **Vent** para **Applications** e abra-o.
3. Siga a configuração para instalar o auxiliar. O macOS pedirá uma senha de administrador porque mudar velocidades de ventiladores exige privilégios elevados.
4. Escolha **Auto Temp**, depois sua temperatura alvo — ou escolha um perfil.

O empacotamento atual usa assinatura ad-hoc, e não notarização com Developer ID, portanto o macOS pode bloquear o aplicativo baixado. Analise o código-fonte e a versão antes de decidir se permitirá sua execução nas configurações de segurança do macOS.

**Requer macOS 13+ e um Mac com ventiladores controláveis.** O projeto inclui suporte a Intel e Apple Silicon, mas a disponibilidade dos sensores e o controle dos ventiladores variam conforme o modelo. Um MacBook Air sem ventilador não tem ventilador para controlar. [Relate a compatibilidade](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml) em vez de presumir que todos os modelos são compatíveis.

## ↩️ Voltar ao controle do macOS

> [!IMPORTANT]
> **Fechar o painel preserva o modo de ventilador escolhido; sair do Vent devolve os ventiladores ao controle Auto do macOS.**

Antes de sair, o aplicativo espera que o auxiliar `ventd` confirme Auto; se não puder confirmar, o Vent permanece aberto e mostra um erro. Settings também oferece **Uninstall Helper**, que retorna os ventiladores a Auto e remove o auxiliar. Exclua o aplicativo separadamente se não precisar mais dele.

## 🔒 Privacidade

Sem conta e sem análises. O controle dos ventiladores acontece localmente por meio de um Unix socket entre o aplicativo e `ventd`.

**As verificações automáticas de atualização estão ativadas por padrão** e entram em contato com o GitHub para obter informações de versão. Baixar uma atualização também usa a rede. Desative **Automatically check for updates** em Settings se não quiser verificações automáticas.

## 💚 Ajude o Vent a chegar a mais Macs

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Dar uma estrela ao Vent no GitHub"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Enviar um relatório de compatibilidade"></a>
</p>

Se o Vent for útil para você, dê uma estrela ao repositório, compartilhe-o com alguém que precise dele ou envie um relatório de compatibilidade. Relatos de bugs, traduções e pull requests também ajudam.

Ao relatar um problema de hardware, inclua o modelo do seu Mac, a versão do macOS, o que você esperava e a saída de:

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ Compilar e contribuir

Instruções de compilação, exemplos de CLI e arquitetura: [guia do desenvolvedor](docs/DEVELOPMENT.md).

## Licença

[MIT](LICENSE). Use, examine e melhore.
