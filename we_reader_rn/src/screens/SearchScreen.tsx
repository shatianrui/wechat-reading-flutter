import React, { useMemo, useState } from 'react';
import { FlatList, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';
import { sampleBooks } from '../data/sampleBooks';
import BookCover from '../components/BookCover';

type Props = NativeStackScreenProps<RootStackParamList, 'Search'>;

export default function SearchScreen({ navigation }: Props) {
  const [query, setQuery] = useState('');

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return sampleBooks.filter(
      (b) =>
        b.title.toLowerCase().includes(q) ||
        b.author.toLowerCase().includes(q) ||
        b.category.toLowerCase().includes(q)
    );
  }, [query]);

  return (
    <View style={styles.container}>
      <View style={styles.searchRow}>
        <TextInput
          autoFocus
          value={query}
          onChangeText={setQuery}
          placeholder="搜索书名、作者、分类"
          style={styles.input}
        />
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Text style={styles.cancel}>取消</Text>
        </TouchableOpacity>
      </View>
      <FlatList
        data={results}
        keyExtractor={(b) => b.id}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={styles.row}
            onPress={() => navigation.replace('BookDetail', { bookId: item.id })}
          >
            <BookCover book={item} width={48} height={64} />
            <View style={{ marginLeft: 12, flex: 1 }}>
              <Text style={styles.title}>{item.title}</Text>
              <Text style={styles.subtitle}>
                {item.author} · {item.category}
              </Text>
            </View>
          </TouchableOpacity>
        )}
        ListEmptyComponent={
          query.trim().length > 0 ? <Text style={styles.empty}>没有找到相关书籍</Text> : null
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFFFF', paddingTop: 8 },
  searchRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, marginBottom: 8 },
  input: {
    flex: 1,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#F1F1F3',
    paddingHorizontal: 16,
  },
  cancel: { marginLeft: 12, color: '#2B2B2B' },
  row: { flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 10, alignItems: 'center' },
  title: { fontSize: 15, fontWeight: '600' },
  subtitle: { color: '#8A8778', fontSize: 12, marginTop: 4 },
  empty: { textAlign: 'center', color: '#999', marginTop: 40 },
});
