import React, { useMemo, useState } from 'react';
import { FlatList, Pressable, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';
import { sampleBooks, bookCategories } from '../data/sampleBooks';
import type { Book } from '../types/models';
import BookCover from '../components/BookCover';

interface Props {
  navigation: NativeStackNavigationProp<RootStackParamList>;
}

function RankingCard({ title, books, onPress }: { title: string; books: Book[]; onPress: (id: string) => void }) {
  return (
    <View style={styles.rankingCard}>
      <Text style={styles.rankingTitle}>{title}</Text>
      {books.slice(0, 3).map((b, i) => (
        <TouchableOpacity key={b.id} style={styles.rankingRow} onPress={() => onPress(b.id)}>
          <Text style={styles.rankingIndex}>{i + 1}</Text>
          <Text style={styles.rankingBookTitle} numberOfLines={1}>
            {b.title}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );
}

function BookListTile({ book, onPress }: { book: Book; onPress: () => void }) {
  return (
    <TouchableOpacity style={styles.listTile} onPress={onPress}>
      <BookCover book={book} width={64} height={86} />
      <View style={styles.listTileInfo}>
        <Text style={styles.listTileTitle} numberOfLines={1}>
          {book.title}
        </Text>
        <Text style={styles.listTileAuthor} numberOfLines={1}>
          {book.author} · {book.category}
        </Text>
        <Text style={styles.listTileIntro} numberOfLines={2}>
          {book.intro}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

export default function DiscoverScreen({ navigation }: Props) {
  const [category, setCategory] = useState('全部');

  const topRated = useMemo(() => [...sampleBooks].sort((a, b) => b.rating - a.rating), []);
  const topReaders = useMemo(() => [...sampleBooks].sort((a, b) => b.readers - a.readers), []);
  const newest = useMemo(() => sampleBooks.filter((b) => b.isNew), []);

  const filtered = useMemo(
    () => (category === '全部' ? sampleBooks : sampleBooks.filter((b) => b.category === category)),
    [category]
  );

  const openDetail = (bookId: string) => navigation.navigate('BookDetail', { bookId });

  return (
    <View style={styles.container}>
      <Pressable style={styles.searchBar} onPress={() => navigation.navigate('Search')}>
        <Text style={styles.searchPlaceholder}>搜索书名、作者</Text>
      </Pressable>

      <FlatList
        data={filtered}
        keyExtractor={(b) => b.id}
        ListHeaderComponent={
          <View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.rankingRowContainer}>
              <RankingCard title="神作榜" books={topRated} onPress={openDetail} />
              <RankingCard title="飙升榜" books={topReaders} onPress={openDetail} />
              <RankingCard title="新书榜" books={newest} onPress={openDetail} />
            </ScrollView>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.categoryRow}>
              {bookCategories.map((c) => (
                <TouchableOpacity
                  key={c}
                  style={[styles.chip, category === c && styles.chipActive]}
                  onPress={() => setCategory(c)}
                >
                  <Text style={[styles.chipText, category === c && styles.chipTextActive]}>{c}</Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        }
        renderItem={({ item }) => <BookListTile book={item} onPress={() => openDetail(item.id)} />}
        contentContainerStyle={{ paddingBottom: 24 }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFFFF' },
  searchBar: {
    margin: 12,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#F1F1F3',
    justifyContent: 'center',
    paddingHorizontal: 16,
  },
  searchPlaceholder: { color: '#9A9A9A' },
  rankingRowContainer: { paddingLeft: 12, marginBottom: 8 },
  rankingCard: {
    width: 180,
    backgroundColor: '#F8F7F4',
    borderRadius: 12,
    padding: 12,
    marginRight: 10,
  },
  rankingTitle: { fontWeight: '700', marginBottom: 8, fontSize: 14 },
  rankingRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 4 },
  rankingIndex: { width: 18, color: '#B08D57', fontWeight: '700' },
  rankingBookTitle: { flex: 1, fontSize: 13 },
  categoryRow: { paddingLeft: 12, marginBottom: 4 },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 16,
    backgroundColor: '#F1F1F3',
    marginRight: 8,
  },
  chipActive: { backgroundColor: '#2B2B2B' },
  chipText: { color: '#555' },
  chipTextActive: { color: '#FFFFFF' },
  listTile: { flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 10 },
  listTileInfo: { flex: 1, marginLeft: 12, justifyContent: 'center' },
  listTileTitle: { fontSize: 16, fontWeight: '700' },
  listTileAuthor: { color: '#8A8778', fontSize: 12, marginTop: 4 },
  listTileIntro: { color: '#666', fontSize: 12, marginTop: 4 },
});
