import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import type { Book } from '../types/models';

interface Props {
  book: Book;
  width: number;
  height: number;
}

/** Procedurally generated cover (gradient-ish two-tone block + title/author), no image asset. */
export default function BookCover({ book, width, height }: Props) {
  const [c1, c2] = book.coverColors;
  return (
    <View style={[styles.container, { width, height, backgroundColor: c1, borderColor: c2 }]}>
      <View style={[styles.accent, { backgroundColor: c2 }]} />
      <Text style={styles.title} numberOfLines={4}>
        {book.title}
      </Text>
      <Text style={styles.author} numberOfLines={1}>
        {book.author}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 8,
    borderWidth: 2,
    padding: 10,
    justifyContent: 'space-between',
    overflow: 'hidden',
  },
  accent: {
    position: 'absolute',
    right: -20,
    top: -20,
    width: 60,
    height: 60,
    borderRadius: 30,
    opacity: 0.6,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  author: {
    color: '#FFFFFF',
    fontSize: 11,
    opacity: 0.85,
  },
});
