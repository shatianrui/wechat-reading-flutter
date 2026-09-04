import React, { useMemo } from 'react';
import { ActionSheetIOS, Alert, FlatList, Platform, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';
import { sampleBooks } from '../data/sampleBooks';
import { useAppState } from '../store/useAppState';
import BookCover from '../components/BookCover';

interface Props {
  navigation: NativeStackNavigationProp<RootStackParamList>;
}

function showActionSheet(
  onDetail: () => void,
  onRemove: () => void
) {
  if (Platform.OS === 'ios') {
    ActionSheetIOS.showActionSheetWithOptions(
      { options: ['详情', '移出书架', '取消'], cancelButtonIndex: 2, destructiveButtonIndex: 1 },
      (index) => {
        if (index === 0) onDetail();
        if (index === 1) onRemove();
      }
    );
  } else {
    Alert.alert('书籍操作', undefined, [
      { text: '详情', onPress: onDetail },
      { text: '移出书架', style: 'destructive', onPress: onRemove },
      { text: '取消', style: 'cancel' },
    ]);
  }
}

export default function ShelfScreen({ navigation }: Props) {
  const shelf = useAppState((s) => s.shelf);
  const progress = useAppState((s) => s.progress);
  const removeFromShelf = useAppState((s) => s.removeFromShelf);

  const items = useMemo(
    () => shelf.map((id) => sampleBooks.find((b) => b.id === id)).filter((b): b is NonNullable<typeof b> => !!b),
    [shelf]
  );

  if (items.length === 0) {
    return (
      <View style={styles.empty}>
        <Text style={styles.emptyText}>书架还是空的，去发现页找本书吧</Text>
      </View>
    );
  }

  return (
    <FlatList
      data={items}
      keyExtractor={(b) => b.id}
      numColumns={3}
      contentContainerStyle={{ padding: 12 }}
      renderItem={({ item }) => {
        const p = progress[item.id];
        const percent = p ? Math.round(p.percent * 100) : 0;
        return (
          <TouchableOpacity
            style={styles.cell}
            onPress={() => navigation.navigate('Reader', { bookId: item.id })}
            onLongPress={() =>
              showActionSheet(
                () => navigation.navigate('BookDetail', { bookId: item.id }),
                () => removeFromShelf(item.id)
              )
            }
          >
            <BookCover book={item} width={96} height={130} />
            <Text style={styles.title} numberOfLines={1}>
              {item.title}
            </Text>
            <Text style={styles.percent}>{percent > 0 ? `已读 ${percent}%` : '未开始'}</Text>
          </TouchableOpacity>
        );
      }}
    />
  );
}

const styles = StyleSheet.create({
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  emptyText: { color: '#999' },
  cell: { flex: 1 / 3, alignItems: 'center', marginBottom: 18 },
  title: { fontSize: 12, marginTop: 6, maxWidth: 96, textAlign: 'center' },
  percent: { fontSize: 10, color: '#999', marginTop: 2 },
});
