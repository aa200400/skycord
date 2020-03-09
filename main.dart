import 'dart:io';
import 'dart:math';

import 'package:nyxx/Vm.dart' hide User;
import 'package:nyxx/commands.dart';
import 'package:nyxx/nyxx.dart' hide User;
import 'package:skyscrapeapi/data_types.dart';

import 'extensions.dart';
import 'skycord_user.dart';

final users = Map<Snowflake, SkycordUser>(); // TODO: Persist data

main() async {
  final bot = NyxxVm(Platform.environment["SKYCORD_DISCORD_TOKEN"]);
  CommandsFramework(bot, prefix: "s!")..discoverCommands();

  bot.onReady.first.then((event) => print("Bot ready"));
}

@Command("help")
Future<void> help(CommandContext ctx) async {
  ctx.reply(content: "s!help - Display a help message\n"
      "s!login - Interactive login (Does not work in DMs)\n"
      "s!oldlogin [skyward url] [username] [password] - Login to skycord\n"
      "s!roulette - Display a random assignment");
}

@Command("login")
Future<void> login(CommandContext ctx) async {
  if ((await ctx.author.dmChannel) == ctx.channel) {
    ctx.reply(content: "Interactive login is known to have issues in direct messages, use s!oldlogin");
    return;
  }

  ctx.reply(content: "Skyward URL?");
  final skywardUrl = (await ctx.nextMessageByAuthor()).message.content;
  ctx.reply(content: "Username?");
  final username = (await ctx.nextMessageByAuthor()).message.content;
  ctx.reply(content: "Password?");
  final password = (await ctx.nextMessageByAuthor()).message.content;
  final skycordUser = SkycordUser()
    ..skywardUrl = skywardUrl
    ..username = username
    ..password = password;

  await ctx.channel.send(content: "Validating credentials...");
  ctx.channel.startTypingLoop();
  try {
    final user = await skycordUser.getSkywardUser();
    users[ctx.author.id] = skycordUser;
    ctx.channel.send(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.channel.send(content: "Login failed");
  } finally {
    ctx.channel.stopTypingLoop();
  }
}

@Command("oldlogin")
Future<void> oldLogin(CommandContext ctx) async {
  final splitContent = ctx.message.content.split(" ");
  if (splitContent.length != 4) {
    ctx.reply(content: "Invalid number of arguments");
    return;
  }
  await ctx.reply(content: "Validating credentials...");
  ctx.channel.startTypingLoop();
  final skycordUser = SkycordUser()
    ..skywardUrl = splitContent[1]
    ..username = splitContent[2]
    ..password = splitContent[3];

  try {
    final user = await skycordUser.getSkywardUser();
    users[ctx.author.id] = skycordUser;
    ctx.reply(content: "Logged in as " + await user.getName());
  } catch (error) {
    ctx.reply(content: "Login failed");
  } finally {
    ctx.channel.stopTypingLoop();
  }
}

@Command("roulette", typing: true)
Future<void> roulette(CommandContext ctx) async {
  if (users.containsKey(ctx.author.id)) {
    final skycordUser = users[ctx.author.id];
    final user = await skycordUser.getSkywardUser();
    final gradebook = await user.getGradebook();
    final assignments = await gradebook.quickAssignments;
    final assignment = await assignments[Random().nextInt(assignments.length)];
    final assignmentDetails = await user.getAssignmentDetailsFrom(assignment);
    final skywardName = await user.getName();
    final embed = EmbedBuilder()
      ..title = "${assignment.assignmentName} (${assignment.getIntGrade() ?? "Empty"})"
      ..description
      ..timestamp = DateTime.now().toUtc()
      ..addAuthor((author)  {
        author.name = skywardName;
        author.iconUrl = ctx.author.avatarURL();
      })
      ..addFooter((footer) { // TODO: Add icon
        footer.text = "Powered by SkyScrapeAPI";
      });
    for (AssignmentProperty property in assignmentDetails)
      embed.addField(name: property.infoName, content: property.info.isNullOrBlank() ? "Empty" : property.info, inline: true);

    ctx.reply(embed: embed);
  } else {
    ctx.reply(content: "Not yet registered");
  }
}
