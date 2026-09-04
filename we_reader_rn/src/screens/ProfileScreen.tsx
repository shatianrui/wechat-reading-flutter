import React from 'react';
import { Alert, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useAppState } from '../store/useAppState';

function StatItem({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statItem}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function formatMinutes(seconds: number): string {
  return `${Math.round(seconds / 60)} 分钟`;
}

export default function ProfileScreen() {
  const total = useAppState((s) => s.totalReadingSeconds());
  const today = useAppState((s) => s.todayReadingSeconds());
  const days = useAppState((s) => s.readingDays());
  const notes = useAppState((s) => s.noteCount());

  const openStub = () => Alert.alert('开发中', '该功能正在开发中');

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <View style={styles.avatar} />
        <Text style={styles.username}>微读用户</Text>
      </View>

      <View style={styles.statsRow}>
        <StatItem label="累计阅读" value={formatMinutes(total)} />
        <StatItem label="今日阅读" value={formatMinutes(today)} />
        <StatItem label="阅读天数" value={`${days} 天`} />
        <StatItem label="想法数" value={`${notes} 条`} />
      </View>

      {['云同步', '会员卡', '设置'].map((label) => (
        <TouchableOpacity key={label} style={styles.tile} onPress={openStub}>
          <Text style={styles.tileText}>{label}</Text>
          <Text style={styles.tileArrow}>›</Text>
        </TouchableOpacity>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#FFFFFF' },
  header: { alignItems: 'center', paddingVertical: 28 },
  avatar: { width: 64, height: 64, borderRadius: 32, backgroundColor: '#DDD' },
  username: { marginTop: 10, fontSize: 16, fontWeight: '600' },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around', paddingVertical: 16 },
  statItem: { alignItems: 'center' },
  statValue: { fontSize: 16, fontWeight: '700' },
  statLabel: { fontSize: 12, color: '#999', marginTop: 4 },
  tile: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#EEE',
  },
  tileText: { fontSize: 15 },
  tileArrow: { color: '#CCC', fontSize: 18 },
});
