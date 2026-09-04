import React, { useEffect, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import type { RootStackParamList } from '../navigation/types';
import { sampleBooks } from '../data/sampleBooks';
import { bookRepository } from '../data/bookRepository';
import type { Chapter } from '../types/models';
import BookCover from '../components/BookCover';
import { useAppState } from '../store/useAppState';

type Props = NativeStackScreenProps<RootStackParamList, 'BookDetail'>;

export default function BookDetailScreen({ route, navigation }: Props) {
  const book = sampleBooks.find((b) => b.id === route.params.bookId);
  const [chapters, setChapters] = useState<Chapter[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const isOnShelf = useAppState((s) => (book ? s.isOnShelf(book.id) : false));
  const addToShelf = useAppState((s) => s.addToShelf);

  useEffect(() => {
    if (!book) return;
    bookRepository
      .loadChapters(book)
      .then(setChapters)
      .catch((e) => setError(String(e?.message ?? e)));
  }, [book]);

  if (!book) {
    return (
      <View style={styles.center}>
        <Text>书籍不存在</Text>
      </View>
    );
  }

  const openReader = (initialChapterIndex?: number) => {
    navigation.navigate('Reader', { bookId: book.id, initialChapterIndex });
  };

  return (
    <View style={{ flex: 1, backgroundColor: '#FFFFFF' }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 90 }}>
        <View style={styles.header}>
          <BookCover book={book} width={100} height={136} />
          <View style={styles.headerInfo}>
            <Text style={styles.title}>{book.title}</Text>
            <Text style={styles.author}>{book.author}</Text>
            <View style={styles.chipRow}>
              <Text style={styles.chip}>{book.category}</Text>
              <Text style={styles.chip}>评分 {book.rating}</Text>
              <Text style={styles.chip}>{book.readers} 人在读</Text>
            </View>
          </View>
        </View>

        <Text style={styles.sectionTitle}>简介</Text>
        <Text style={styles.intro}>{book.intro}</Text>

        <Text style={styles.sectionTitle}>目录</Text>
        {error ? (
          <Text style={styles.error}>加载失败：{error}</Text>
        ) : !chapters ? (
          <ActivityIndicator style={{ marginTop: 16 }} />
        ) : (
          chapters.map((c, i) => (
            <TouchableOpacity key={i} style={styles.chapterRow} onPress={() => openReader(i)}>
              <Text style={styles.chapterTitle} numberOfLines={1}>
                {c.title}
              </Text>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>

      <View style={styles.bottomBar}>
        <TouchableOpacity
          style={styles.secondaryBtn}
          onPress={() => addToShelf(book.id)}
        >
          <Text style={styles.secondaryBtnText}>{isOnShelf ? '已在书架' : '加入书架'}</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.secondaryBtn} onPress={() => openReader(undefined)}>
          <Text style={styles.secondaryBtnText}>听书</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.primaryBtn} onPress={() => openReader(undefined)}>
          <Text style={styles.primaryBtnText}>阅读</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', padding: 16 },
  headerInfo: { marginLeft: 16, flex: 1, justifyContent: 'center' },
  title: { fontSize: 20, fontWeight: '700' },
  author: { color: '#8A8778', marginTop: 6 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap', marginTop: 10 },
  chip: {
    fontSize: 11,
    color: '#666',
    backgroundColor: '#F1F1F3',
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 3,
    marginRight: 6,
    marginBottom: 6,
  },
  sectionTitle: { fontSize: 15, fontWeight: '700', marginTop: 8, marginHorizontal: 16, marginBottom: 8 },
  intro: { marginHorizontal: 16, color: '#444', lineHeight: 20 },
  error: { marginHorizontal: 16, color: '#C0392B' },
  chapterRow: { paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#EEE' },
  chapterTitle: { fontSize: 14, color: '#333' },
  bottomBar: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    flexDirection: 'row',
    padding: 12,
    gap: 10,
    backgroundColor: '#FFFFFF',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderColor: '#EEE',
  },
  secondaryBtn: {
    flex: 1,
    height: 44,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: '#DDD',
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryBtnText: { color: '#333', fontWeight: '600' },
  primaryBtn: {
    flex: 1,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#2B2B2B',
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryBtnText: { color: '#FFFFFF', fontWeight: '700' },
});
