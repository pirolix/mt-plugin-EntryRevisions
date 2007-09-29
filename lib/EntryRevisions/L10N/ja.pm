package EntryRevisions::L10N::ja;

use strict;
use base qw( EntryRevisions::L10N::en_us );
use vars qw( %Lexicon );

%Lexicon = (
'Piroli YUKARINOMIYA'
    => '紫京 ぴろり',
'Automatically storing the version copies of entry when it saved, and you can revert the contents of entry from the stored version copies.'
    => '記事が保存される際にそのバージョンコピーを自動的に保存し，保存されたバージョンコピーから過去のバージョンに戻すことができます。',
# config.tmpl
'Configure the version copies to store. The version copies are stored in the other blogs as a new entry on each saving the entry.'
    => '保存されるバージョンコピーについて設定します。バージョンコピーは保存される度に他のブログの新しいエントリとして保存されます。',
'*DO NOT* configure the each blogs in their circulating reference. It may cause the system hunged up.'
    => '指定されたブログが互いに循環参照とならないようにしてください。場合によって暴走するかもしれません！',
'Version copies'
    => 'コピーの数',
'Set the number of version copies of entry to store. Increasing the number enables you to retrieve the distance past, but also increases the size of repository database.'
    => '保存するバージョンコピーの数を指定します。大きな数を指定することでより過去のバージョンに遡ることができますが，データベースが肥大化するので注意してください。',
# 33/message_new.tmpl
'Just showing the selected version. If you want to retrieve this version, save the entry.'
    => '選択されたバージョンを表示しています。このバージョンを反映するにはエントリを保存してください。',
# 33/versions-tab_new.tmpl
'Versions'
    => '履歴保存',
# 33/versions-panel_new.tmpl
'Versions of entry'
    => 'バージョンの管理',
'List below is the stored versions of this entry. Select a version and the version you selected is shown, but not yet been saved. If that copy is what you want, you can revert the entry with saving the shown entry.'
    => '保存されているバージョンコピーの一覧です。戻したいバージョンを選択すると，そのバージョンコピーが表示されますが，まだ反映はされていません。そのコピーが希望したものであれば，そのまま保存することでエントリ内容を過去のバージョンに戻すことができます。',
'Revision'
    => 'リビジョン',
'Latest'
    => '最新の版',
'No Version copy exist for this entry.'
    => 'このエントリーにはバージョンコピーがありません。',
);

1;
