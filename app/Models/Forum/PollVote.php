<?php

/**
 *    Copyright 2016 ppy Pty. Ltd.
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
namespace App\Models\Forum;

use App\Models\User;
use App\Traits\Validatable;
use Carbon\Carbon;
use DB;
use Illuminate\Database\Eloquent\Model;

class PollVote extends Model
{
    use Validatable;

    protected $table = 'phpbb_poll_votes';
    protected $guarded = [];
    public $timestamps = false;

    public function pollOption()
    {
        return $this
            ->belongsTo(PollOption::class, 'poll_option_id', 'poll_option_id')
            ->where('topic_id', $this->topic_id);
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'vote_user_id');
    }

    public function validationErrorsTranslationPrefix()
    {
        return 'forum.poll_vote';
    }

    public function isValid()
    {
        $this->validationErrors()->reset();

        if ($this->pollOption === null) {
            $this->validationErrors()->add('poll_option_id', '.invalid');
        }

        return $this->validationErrors()->isAny();
    }

    public static function do($topic, $optionIds, $user, $ip)
    {
        // some kind of validation
        if (count($optionIds) > $topic->poll_max_options) {
            return false;
        }

        return DB::transaction(function () use ($topic, $optionIds, $user, $ip) {
            $topic->update([
                'poll_last_vote' => Carbon::now(),
            ]);

            $topic
                ->pollVotes()
                ->where('vote_user_id', $user->getKey())
                ->delete();

            foreach (array_unique($optionIds) as $optionId) {
                $topic
                    ->pollVotes()
                    ->create([
                        'poll_option_id' => $optionId,
                        'vote_user_id' => $user->getKey(),
                        'vote_user_ip' => $ip,
                    ]);
            }

            PollOption::updateTotals(['topic_id' => $topic->getKey()]);

            return true;
        });
    }
}
