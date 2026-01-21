"""
Sequence Packing
================

Pack multiple sequences into fixed-length chunks for efficient training.
"""

from dataclasses import dataclass, field
from typing import List, Optional, Iterator, Tuple
import random


@dataclass
class PackingConfig:
    """Configuration for sequence packing."""
    max_seq_length: int = 4096
    pad_token_id: int = 0
    eos_token_id: int = 2
    shuffle: bool = True
    seed: int = 42


@dataclass
class PackedBatch:
    """A packed batch of sequences."""
    input_ids: List[int]
    attention_mask: List[int]
    position_ids: List[int]
    sequence_boundaries: List[Tuple[int, int]]  # (start, end) for each sequence


class SequencePacker:
    """
    Pack multiple sequences into fixed-length chunks.
    
    Reduces padding waste and improves training efficiency.
    
    Example:
        >>> packer = SequencePacker(max_seq_length=4096)
        >>> packed = packer.pack(sequences)
    """
    
    def __init__(self, config: Optional[PackingConfig] = None):
        self.config = config or PackingConfig()
        if self.config.shuffle:
            random.seed(self.config.seed)
    
    def pack(self, sequences: List[List[int]]) -> List[PackedBatch]:
        """Pack sequences into fixed-length batches."""
        if self.config.shuffle:
            sequences = sequences.copy()
            random.shuffle(sequences)
        
        packed_batches = []
        current_ids = []
        current_mask = []
        current_positions = []
        boundaries = []
        
        for seq in sequences:
            # Add EOS if not present
            if seq[-1] != self.config.eos_token_id:
                seq = seq + [self.config.eos_token_id]
            
            # Check if sequence fits
            if len(current_ids) + len(seq) <= self.config.max_seq_length:
                # Add to current batch
                start = len(current_ids)
                current_ids.extend(seq)
                current_mask.extend([1] * len(seq))
                current_positions.extend(range(len(seq)))
                boundaries.append((start, len(current_ids)))
            else:
                # Finalize current batch
                if current_ids:
                    packed_batches.append(self._finalize_batch(
                        current_ids, current_mask, current_positions, boundaries
                    ))
                
                # Start new batch
                current_ids = seq.copy()
                current_mask = [1] * len(seq)
                current_positions = list(range(len(seq)))
                boundaries = [(0, len(seq))]
        
        # Finalize last batch
        if current_ids:
            packed_batches.append(self._finalize_batch(
                current_ids, current_mask, current_positions, boundaries
            ))
        
        return packed_batches
    
    def _finalize_batch(
        self,
        ids: List[int],
        mask: List[int],
        positions: List[int],
        boundaries: List[Tuple[int, int]],
    ) -> PackedBatch:
        """Pad and finalize a batch."""
        pad_length = self.config.max_seq_length - len(ids)
        
        if pad_length > 0:
            ids = ids + [self.config.pad_token_id] * pad_length
            mask = mask + [0] * pad_length
            positions = positions + [0] * pad_length
        
        return PackedBatch(
            input_ids=ids,
            attention_mask=mask,
            position_ids=positions,
            sequence_boundaries=boundaries,
        )
    
    def pack_streaming(self, sequences: Iterator[List[int]]) -> Iterator[PackedBatch]:
        """Stream-based packing."""
        current_ids = []
        current_mask = []
        current_positions = []
        boundaries = []
        
        for seq in sequences:
            if seq[-1] != self.config.eos_token_id:
                seq = seq + [self.config.eos_token_id]
            
            if len(current_ids) + len(seq) <= self.config.max_seq_length:
                start = len(current_ids)
                current_ids.extend(seq)
                current_mask.extend([1] * len(seq))
                current_positions.extend(range(len(seq)))
                boundaries.append((start, len(current_ids)))
            else:
                if current_ids:
                    yield self._finalize_batch(
                        current_ids, current_mask, current_positions, boundaries
                    )
                
                current_ids = seq.copy()
                current_mask = [1] * len(seq)
                current_positions = list(range(len(seq)))
                boundaries = [(0, len(seq))]
        
        if current_ids:
            yield self._finalize_batch(
                current_ids, current_mask, current_positions, boundaries
            )
    
    def get_efficiency(self, batches: List[PackedBatch]) -> float:
        """Calculate packing efficiency (non-padding ratio)."""
        total_tokens = 0
        non_pad_tokens = 0
        
        for batch in batches:
            total_tokens += len(batch.input_ids)
            non_pad_tokens += sum(batch.attention_mask)
        
        return non_pad_tokens / total_tokens if total_tokens > 0 else 0


def pack_sequences(
    sequences: List[List[int]],
    max_seq_length: int = 4096,
    **kwargs
) -> List[PackedBatch]:
    """Convenience function for sequence packing."""
    config = PackingConfig(max_seq_length=max_seq_length, **kwargs)
    packer = SequencePacker(config)
    return packer.pack(sequences)
