<?php

/**
 *    Copyright 2015 ppy Pty. Ltd.
 *
 *    This file is part of osu!web. osu!web is distributed with the hope of
 *    attracting more community contributions to the core ecosystem of osu!.
 *
 *    osu!web is free software: you can redistribute it and/or modify
 *    it under the terms of the Affero GNU General Public License version 3
 *    as published by the Free Software Foundation.
 *
 *    osu!web is distributed WITHOUT ANY WARRANTY; without even the implied
 *    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *    See the GNU Affero General Public License for more details.
 *
 *    You should have received a copy of the GNU Affero General Public License
 *    along with osu!web.  If not, see <http://www.gnu.org/licenses/>.
 */
namespace App\Transformers\Forum;

use App\Models\Forum\ForumCover;
use League\Fractal;

class ForumCoverTransformer extends Fractal\TransformerAbstract
{
    public function transform(ForumCover $cover = null)
    {
        $forumId = $cover !== null ? $cover->forum_id : null;

        if ($cover === null || $cover->id === null) {
            $data = [
                'method' => 'post',
                'url' => route('forum.forum-covers.store', ['forum_id' => $forumId]),
            ];
        } else {
            $data = [
                'method' => 'put',
                'url' => route('forum.forum-covers.update', [$cover, 'forum_id' => $forumId]),

                'id' => $cover->id,
                'fileUrl' => $cover->fileUrl(),
            ];
        }

        $data['dimensions'] = $cover->maxDimensions;

        return $data;
    }
}
