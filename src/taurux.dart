import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:args/args.dart';
import 'dart:convert';
import 'dart:io';

import 'util.dart';

var debug = false;
var showDownloadLink = false;
var best = false;
var globalName = null;

const availableBitRates = ['64', '128', '192', '256'];

const cbrOption = 'cbr';
const dryRunFlag = 'dry-run';
const debugFlag = 'debug';
const helpFlag = 'help';
const targetOption = 'target';
const showLinkFlag = 'show-link';
const bestTryFlag = 'best-try';
const nameOption = 'name';

main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('No arguments');
    exit(1);
  }

  final argParser = new ArgParser()
    ..addOption(cbrOption, abbr: 'c',
      allowed: availableBitRates,
      help: 'Specify the constant bit rate')..addOption(
      targetOption, defaultsTo: '.',
      help: 'specify a target directory')..addOption(
      nameOption, help: 'specify a name')
    ..addFlag(dryRunFlag, negatable: false,
      abbr: 'd',
      help: 'dry run without download')..addFlag(
      bestTryFlag, help: 'try to find best cbr', abbr: 'b')..addFlag(
      showLinkFlag, negatable: false,
      help: 'display the download link')..addFlag(debugFlag, negatable: false,
      abbr: 'D',
      help: 'specify debug mode')..addFlag(
      helpFlag, negatable: false, abbr: 'h', help: 'Show Usage');

  ArgResults argResults;
  try {
    argResults = argParser.parse(arguments);
  } catch (e) {
    print('Error: Wrong option or flag');
    exit(1);
  }

  if (argResults[helpFlag]) {
    print(argParser.usage);
    exit(0);
  }

  debug = argResults[debugFlag];
  showDownloadLink = argResults[showLinkFlag];
  best = argResults[bestTryFlag];
  globalName = argResults[nameOption];

  var rest = argResults.rest;

  if (rest.isEmpty) {
    print('There are no links to download...');
    exit(0);
  }

  if (!argResults[dryRunFlag]) {
    for (var link in rest) {
      dl(link, argResults[cbrOption], argResults[targetOption]);
    }
  }
}

getBestTry(String link) async {
  var cbrs = availableBitRates;
  for (var i = cbrs.length - 1; i >= 0; i--) {
    http.Response res = await http.get('$link${cbrs[i]}');
    if (isOk(res.statusCode)) {
      return '$link${cbrs[i]}';
    }
  }
}

dl(String link, String cbr, String target) async {
  var name = splitLink(link);
  try {
    http.Response response = await http.get(link);
    Document document = parser.parse(response.body);

    var x = document.getElementsByTagName('script')
      .where((Element el) => el.text.contains('INITIAL'))
      .map((Element el) => el.text.substring(27))
      .toList().toString();
    var sub1 = x.substring(x.indexOf(name));
    var base = '${sub1.substring(
      sub1.indexOf('audioURL') + 11, sub1.indexOf('background') - 3)}?cbr=';
    var dl = cbr == null
      ? (best ? await getBestTry(base) : '$base${128}')
      : '$base$cbr';

    if (showDownloadLink) {
      print(dl);
      exit(0);
    }

    if (debug) print(dl);

    new HttpClient().getUrl(Uri.parse(dl))
      .then((HttpClientRequest request) => request.close())
      .then((HttpClientResponse response) {
      if (debug) print('Status Code: ${response.statusCode}');

      if (isOk(response.statusCode)) {
        print('Writing bytes...');
        response.pipe(
          new File('$target/${globalName ?? name}.mp3').openWrite());
      } else {
        print('Resource not available');
        exit(1);
      }
    });
  } catch (e) {
    print('An error occured, Please check your previous command');
    exit(1);
  }
}
